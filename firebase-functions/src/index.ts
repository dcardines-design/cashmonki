import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import express, { Request, Response, NextFunction } from "express";
import cors from "cors";
import multer from "multer";
import sharp from "sharp";
import fetch from "node-fetch";
import * as logger from "firebase-functions/logger";

// Define secrets for Firebase Functions v2
const openRouterApiKey = defineSecret('OPENROUTER_API_KEY');
const revenueCatApiKey = defineSecret('REVENUECAT_TEST_API_KEY');

// Extend Express Request interface
interface AuthenticatedRequest extends Request {
  user?: any;
  startTime?: number;
}

// Initialize Firebase Admin
initializeApp();

const app = express();

// Configure CORS for your app and iOS clients
app.use(cors({
  origin: [
    'cashmonki.app',
    'https://cashmonki.app',
    'https://www.cashmonki.app'
  ],
  credentials: true
}));

// Allow iOS app requests (they don't have an origin header)
app.use((req, res, next) => {
  // Allow iOS requests without origin
  if (!req.headers.origin) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  }
  next();
});

app.use(express.json({ limit: '10mb' }));

// Add request timing middleware - MUST be before routes
app.use((req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  req.startTime = Date.now();
  next();
});

// Configure multer for image uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB max
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'));
    }
  }
});

// Middleware to verify Firebase Auth token (required)
async function verifyAuth(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Missing or invalid authorization header' });
      return;
    }

    const idToken = authHeader.split('Bearer ')[1];
    const decodedToken = await getAuth().verifyIdToken(idToken);
    req.user = decodedToken;
    next();
  } catch (error) {
    logger.error('Auth verification failed:', error);
    res.status(401).json({ error: 'Invalid authentication token' });
    return;
  }
}

// Middleware for optional Firebase Auth (allows unauthenticated requests for no-auth flow)
async function optionalAuth(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
  try {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const idToken = authHeader.split('Bearer ')[1];
      const decodedToken = await getAuth().verifyIdToken(idToken);
      req.user = decodedToken;
      logger.info('Optional auth: User authenticated');
    } else {
      logger.info('Optional auth: No auth token provided, proceeding without authentication');
    }
    next();
  } catch (error) {
    logger.warn('Optional auth: Token verification failed, proceeding without authentication');
    next();
  }
}

// Rate limiting store (in production, use Redis or Firestore)
const rateLimitStore = new Map<string, { count: number; resetTime: number }>();

function checkRateLimit(userId: string, maxRequests: number = 10, windowMs: number = 3600000): boolean {
  const now = Date.now();
  const userLimit = rateLimitStore.get(userId);
  
  if (!userLimit || now > userLimit.resetTime) {
    rateLimitStore.set(userId, { count: 1, resetTime: now + windowMs });
    return true;
  }
  
  if (userLimit.count >= maxRequests) {
    return false;
  }
  
  userLimit.count++;
  return true;
}

// MARK: - Helper Functions

// Format categories passed from iOS app (local storage) into text for AI prompt
function formatPassedCategories(categories: any[]): string {
  if (!categories || !Array.isArray(categories) || categories.length === 0) {
    return '';
  }

  const expenseCategories: string[] = [];
  const incomeCategories: string[] = [];

  for (const category of categories) {
    if (!category.isDeleted) {
      const categoryName = category.name;
      const subcategories = category.subcategories || [];

      // Format: "Category Name (Subcategory1, Subcategory2)"
      let categoryText = categoryName;
      if (subcategories.length > 0) {
        const subcategoryNames = subcategories.map((sub: any) => sub.name).join(', ');
        categoryText += ` (${subcategoryNames})`;
      }

      if (category.type === 'income') {
        incomeCategories.push(categoryText);
      } else {
        expenseCategories.push(categoryText);
      }
    }
  }

  let categoriesText = "Categories: Choose the most specific category from this list:\n\n";

  if (expenseCategories.length > 0) {
    categoriesText += "EXPENSE CATEGORIES:\n";
    categoriesText += expenseCategories.join(', ');
    categoriesText += "\n\n";
  }

  if (incomeCategories.length > 0) {
    categoriesText += "INCOME CATEGORIES:\n";
    categoriesText += incomeCategories.join(', ');
    categoriesText += "\n\n";
  }

  categoriesText += "IMPORTANT: Always prefer the SPECIFIC subcategory name over the parent category. For example, if someone buys coffee, return 'Coffee' NOT 'Drinks'. Return ONLY the subcategory name, not 'Drinks > Coffee'.";

  logger.info(`Formatted ${categories.length} passed categories (${expenseCategories.length} expense, ${incomeCategories.length} income)`);
  return categoriesText;
}

async function fetchUserCategories(userId: string): Promise<string> {
  try {
    const db = getFirestore();
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      logger.info(`User document not found for ${userId}, using default categories`);
      return getDefaultCategoriesText();
    }
    
    const userData = userDoc.data();
    const categories = userData?.categories || [];
    
    if (!categories || categories.length === 0) {
      logger.info(`No custom categories found for ${userId}, using default categories`);
      return getDefaultCategoriesText();
    }
    
    logger.info(`Found ${categories.length} custom categories for user ${userId}`);
    
    // Group categories by type
    const expenseCategories: string[] = [];
    const incomeCategories: string[] = [];
    
    for (const category of categories) {
      if (!category.isDeleted) {
        const categoryName = category.name;
        const subcategories = category.subcategories || [];
        
        // Format: "Category Name (Subcategory1, Subcategory2)"
        let categoryText = categoryName;
        if (subcategories.length > 0) {
          const subcategoryNames = subcategories.map((sub: any) => sub.name).join(', ');
          categoryText += ` (${subcategoryNames})`;
        }
        
        if (category.type === 'income') {
          incomeCategories.push(categoryText);
        } else {
          expenseCategories.push(categoryText);
        }
      }
    }
    
    let categoriesText = "Categories: Choose the most specific category from this list:\n\n";
    
    if (expenseCategories.length > 0) {
      categoriesText += "EXPENSE CATEGORIES:\n";
      categoriesText += expenseCategories.join(', ');
      categoriesText += "\n\n";
    }
    
    if (incomeCategories.length > 0) {
      categoriesText += "INCOME CATEGORIES:\n";
      categoriesText += incomeCategories.join(', ');
      categoriesText += "\n\n";
    }
    
    categoriesText += "IMPORTANT: Always prefer the SPECIFIC subcategory name over the parent category. For example, if someone buys coffee, return 'Coffee' NOT 'Drinks'. Return ONLY the subcategory name, not 'Drinks > Coffee'.";

    return categoriesText;
    
  } catch (error) {
    logger.error(`Error fetching user categories: ${error}`);
    return getDefaultCategoriesText();
  }
}

function getDefaultCategoriesText(): string {
  return `Categories: Choose the most specific category from this list:
                
                EXPENSE CATEGORIES:
                Home (Rent/Mortgage, Property Tax, Home Repairs), Utilities (Electricity, Water, Internet), 
                Food (Groceries, Snacks, Meal Prep), Dining (Restaurants, Cafes, Takeout), 
                Transport (Fuel, Car Payments, Rideshare), Insurance (Auto, Home, Life), 
                Health (Doctor Visits, Medications, Therapy), Debt (Credit Cards, Loans), 
                Fun (Movies, Concerts, Games), Clothes (Work Attire, Casual Wear, Shoes), 
                Personal (Haircuts, Skincare, Hygiene), Learning (Tuition, Books, Courses), 
                Kids (Childcare, Toys, Activities), Pets (Vet Care, Pet Food, Grooming), 
                Gifts (Presents, Donations, Cards), Travel (Flights, Hotels, Rental Cars), 
                Subscriptions (Streaming, Software, Memberships), Household (Cleaning, Furniture, Decor), 
                Services (Legal, Accounting, Professional Consulting), Supplies (Office, Crafts, Packaging), 
                Fitness (Gym, Fitness Equipment, Classes), Tech (Devices, Accessories, Tech Repairs), 
                Business Expenses (Marketing, Inventory, Workspace), Taxes (Income Tax, Sales Tax, Filing Fees), 
                Savings (Emergency Fund, Retirement, Investments), Auto (Maintenance, Registration, Parking), 
                Drinks (Coffee, Alcohol, Beverages), Hobbies (Supplies, Hobby Equipment, Events), 
                Events (Parties, Tickets, Ceremonies), Other (Fees, Miscellaneous, Uncategorized)
                
                INCOME CATEGORIES:
                Salary (Base Salary, Overtime, Bonus), Business Income (Revenue, Business Consulting, Services), 
                Passive (Dividends, Investment Interest, Royalties), Investment (Stocks, Crypto, Real Estate), 
                Government (Tax Refund, Benefits, Stimulus), Miscellaneous (Other Income, Found Money, Cash Back), 
                Refunds (Product Returns, Service Refunds, Insurance Claims), Prizes (Contests, Lottery, Awards), 
                Donations (Gifts Received, Charity Returns, Crowdfunding)
                
                For subcategories (items in parentheses), use the specific subcategory name if it's a better match.`;
}

// MARK: - Receipt Analysis Endpoint

app.post('/api/analyze-receipt', optionalAuth, async (req: AuthenticatedRequest, res: Response) => {
  const requestId = Math.random().toString(36).substr(2, 9);

  // EMERGENCY DEBUG: Use console.log to force output
  console.log(`🚨 [${requestId}] Receipt analysis ENTRY POINT`);
  console.log(`🚨 [${requestId}] Headers:`, Object.keys(req.headers));
  console.log(`🚨 [${requestId}] Content-Type:`, req.headers['content-type']);
  console.log(`🚨 [${requestId}] Body type:`, typeof req.body);
  console.log(`🚨 [${requestId}] Body:`, req.body ? Object.keys(req.body) : 'NULL BODY');

  logger.error(`🚨 EMERGENCY DEBUG [${requestId}] Receipt analysis started`);

  try {
    // Use user ID if authenticated, otherwise use IP address for rate limiting
    const userId = req.user?.uid || req.ip || 'anonymous';
    const isAuthenticated = !!req.user;
    logger.info(`Receipt analysis requested by ${isAuthenticated ? 'authenticated user' : 'anonymous user'}: ${userId}`);

    // Rate limiting
    const rateLimit = 50; // 50 requests/hour for all users
    if (!checkRateLimit(userId, rateLimit, 3600000)) {
      return res.status(429).json({
        error: 'Rate limit exceeded',
        message: 'Too many receipt analysis requests. Please try again in an hour.'
      });
    }

    // Determine which categories to use for AI analysis
    // Priority: 1. Categories passed in request body (from iOS local storage)
    //           2. Categories from Firestore (for authenticated users)
    //           3. Default categories (fallback)
    let userCategoriesText: string;
    const passedCategories = req.body?.categories;

    if (passedCategories && Array.isArray(passedCategories) && passedCategories.length > 0) {
      // Use categories passed from iOS app (works for both auth and unauth users)
      userCategoriesText = formatPassedCategories(passedCategories);
      logger.info(`Using ${passedCategories.length} categories passed from iOS app`);
    } else if (isAuthenticated) {
      // Fetch from Firestore for authenticated users without passed categories
      userCategoriesText = await fetchUserCategories(userId);
      logger.info('Using categories from Firestore for authenticated user');
    } else {
      // Fall back to default categories
      userCategoriesText = getDefaultCategoriesText();
      logger.info('Using default categories (no passed categories, not authenticated)');
    }

    // Debug request details
    logger.info(`📋 REQUEST DETAILS:`);
    logger.info(`Content-Type: ${req.headers['content-type'] || 'NONE'}`);
    logger.info(`Headers: ${JSON.stringify(Object.keys(req.headers))}`);
    logger.info(`Method: ${req.method}`);
    logger.info(`Body type: ${typeof req.body}`);
    logger.info(`Body keys: ${req.body ? Object.keys(req.body) : 'NO BODY'}`);

    // Handle both multipart and JSON requests
    let imageBuffer: Buffer;
    
    if (req.headers['content-type']?.includes('multipart/form-data')) {
      // Multer multipart handling (backup)
      logger.info(`🔧 Taking MULTIPART path`);
      const multerUpload = upload.single('image');
      await new Promise<void>((resolve, reject) => {
        multerUpload(req, res, (err) => {
          if (err) {
            logger.error(`Multer error: ${err}`);
            reject(err);
          } else resolve();
        });
      });
      
      if (!req.file) {
        logger.error(`❌ MULTIPART: No req.file after multer processing`);
        return res.status(400).json({ error: 'No image file provided in multipart' });
      }
      logger.info(`✅ MULTIPART: Got file, size: ${req.file.buffer.length} bytes`);
      imageBuffer = req.file.buffer;
      
    } else {
      // JSON base64 handling (primary)
      console.log(`🚨 [${requestId}] Taking JSON path`);
      console.log(`🚨 [${requestId}] req.body exists:`, !!req.body);
      console.log(`🚨 [${requestId}] req.body type:`, typeof req.body);
      console.log(`🚨 [${requestId}] req.body keys:`, req.body ? Object.keys(req.body) : 'NO BODY');
      
      logger.error(`🚨 EMERGENCY DEBUG Taking JSON path`);
      logger.error(`🚨 JSON Body keys: ${req.body ? Object.keys(req.body) : 'NO BODY'}`);
      
      const { image } = req.body;
      console.log(`🚨 [${requestId}] Extracted image field:`, !!image);
      console.log(`🚨 [${requestId}] Image type:`, typeof image);
      console.log(`🚨 [${requestId}] Image length:`, image?.length || 'N/A');
      
      if (!image) {
        console.log(`🚨 [${requestId}] ERROR: No image field found!`);
        logger.error(`🚨 EMERGENCY No image field found. Body keys: ${req.body ? Object.keys(req.body) : 'NO BODY'}. Body type: ${typeof req.body}`);
        return res.status(400).json({ error: 'No image data provided in JSON', debug: {
          bodyExists: !!req.body,
          bodyType: typeof req.body,
          bodyKeys: req.body ? Object.keys(req.body) : null,
          requestId: requestId
        }});
      }
      
      logger.info(`Image field type: ${typeof image}, length: ${image?.length || 'N/A'}`);
      
      try {
        imageBuffer = Buffer.from(image, 'base64');
        logger.info(`Received base64 image, decoded to ${imageBuffer.length} bytes`);
      } catch (error) {
        logger.error(`Base64 decode error: ${error}`);
        return res.status(400).json({ error: 'Invalid base64 image data' });
      }
    }

    // Process and optimize image
    logger.info('Processing image...');
    const processedImageBuffer = await sharp(imageBuffer)
      .resize({ width: 1024, height: 1024, fit: 'inside', withoutEnlargement: true })
      .jpeg({ quality: 80 })
      .toBuffer();

    const base64Image = processedImageBuffer.toString('base64');
    
    // Get OpenRouter API key from Firebase secrets
    logger.info('🔍 DEBUG: Using Firebase secret for OpenRouter API key');
    const apiKey = openRouterApiKey.value()?.trim();
    
    logger.info('🔍 DEBUG: Final API key exists:', !!apiKey);
    logger.info('🔍 DEBUG: API key length:', apiKey?.length || 0);
    
    if (!apiKey) {
      logger.error('OpenRouter API key not configured');
      return res.status(500).json({ error: 'Receipt analysis service not available' });
    }

    // Determine if we have custom categories passed from the app
    const hasCustomCategories = passedCategories && Array.isArray(passedCategories) && passedCategories.length > 0;

    // Build category instruction - use ONLY custom categories if passed, otherwise use defaults
    const categoryInstruction = hasCustomCategories
      ? `CATEGORY SELECTION - CRITICAL:
                ${userCategoriesText}

                HOW TO CATEGORIZE (waterfall method - use first match):
                1. Look at individual LINE ITEMS first - what was actually purchased?
                2. If multiple items, consider the OVERALL GROUP of items together
                3. Then consider the MERCHANT NAME/TYPE
                4. Finally, use overall CONTEXT of the receipt

                RULES:
                - Use ONLY categories from the list above. Do NOT create new ones.
                - ALWAYS prefer the SPECIFIC subcategory (e.g., "Coffee" NOT "Drinks")
                - Return ONLY the category name, nothing else.
                - If no category matches well, use "Other".`
      : `Available categories (ONLY use these exact categories, do NOT create new ones):
                  * Home: "Home", "Rent/Mortgage", "Property Tax", "Repairs"
                  * Utilities: "Utilities", "Electricity", "Water", "Internet"
                  * Food: "Food", "Groceries", "Snacks", "Meal Prep"
                  * Dining: "Dining", "Restaurants", "Cafes", "Takeout"
                  * Transport: "Transport", "Fuel", "Car Payments", "Rideshare"
                  * Insurance: "Insurance", "Auto Insurance", "Home Insurance", "Life Insurance"
                  * Health: "Health", "Doctor Visits", "Medications", "Therapy"
                  * Debt: "Debt", "Credit Cards", "Loans", "Interest"
                  * Fun: "Fun", "Movies", "Concerts", "Games"
                  * Clothes: "Clothes", "Work Attire", "Casual Wear", "Shoes"
                  * Personal: "Personal", "Haircuts", "Skincare", "Hygiene"
                  * Learning: "Learning", "Tuition", "Books", "Courses"
                  * Kids: "Kids", "Childcare", "Toys", "Activities"
                  * Pets: "Pets", "Vet Care", "Pet Food", "Grooming"
                  * Gifts: "Gifts", "Presents", "Donations", "Cards"
                  * Travel: "Travel", "Flights", "Hotels", "Rental Cars"
                  * Subscriptions: "Subscriptions", "Streaming", "Software", "Memberships"
                  * Household: "Household", "Cleaning", "Furniture", "Decor"
                  * Services: "Services", "Legal", "Accounting", "Consulting"
                  * Supplies: "Supplies", "Office", "Crafts", "Packaging"
                  * Fitness: "Fitness", "Gym", "Equipment", "Classes"
                  * Tech: "Tech", "Devices", "Accessories", "Repairs"
                  * Business: "Business", "Marketing", "Inventory", "Workspace"
                  * Taxes: "Taxes", "Income Tax", "Sales Tax", "Filing Fees"
                  * Savings: "Savings", "Emergency Fund", "Retirement", "Investments"
                  * Auto: "Auto", "Maintenance", "Registration", "Parking"
                  * Drinks: "Drinks", "Coffee", "Alcohol", "Beverages"
                  * Hobbies: "Hobbies", "Supplies", "Equipment", "Events"
                  * Events: "Events", "Parties", "Tickets", "Ceremonies"
                  * Other: "Other", "Fees", "Miscellaneous", "Uncategorized"

                HOW TO CATEGORIZE (waterfall method - use first match):
                1. Look at individual LINE ITEMS first - what was actually purchased?
                2. If multiple items, consider the OVERALL GROUP of items together
                3. Then consider the MERCHANT NAME/TYPE
                4. Finally, use overall CONTEXT of the receipt

                RULES:
                - Use ONLY categories from the list above. Do NOT create new ones.
                - ALWAYS prefer the SPECIFIC subcategory (e.g., "Coffee" NOT "Drinks")
                - Return ONLY the category name, nothing else.
                - If no category matches well, use "Other".`;

    logger.info(`Using ${hasCustomCategories ? 'CUSTOM' : 'DEFAULT'} categories for AI prompt`);

    // Call OpenRouter API
    logger.info('Calling OpenRouter API...');
    const openRouterResponse = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://cashmonki.app',
        'X-Title': 'CashMonki Receipt Analyzer'
      },
      body: JSON.stringify({
        model: 'openai/gpt-4o',
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: `Analyze this receipt image and return ONLY valid JSON in this exact format:
                {
                  "merchant_name": "exact business name from receipt",
                  "amount": 20.50,
                  "currency": "USD",
                  "date": "YYYY-MM-DD or YYYY-MM-DD HH:MM",
                  "category": "category name",
                  "items": [
                    {"name": "item or service name", "price": 20.50, "quantity": 1}
                  ],
                  "confidence": 0.95
                }

                DATE EXTRACTION:
                Take a close look at the receipt to find any references to dates and times, even if the receipt is in another language.
                If you find a date, convert it to YYYY-MM-DD format (e.g., "2025-12-27").
                If you also find a time (like 17:08 or 5:08 PM), include it as YYYY-MM-DD HH:MM in 24-hour format (e.g., "2025-12-27 17:08").
                If no date is visible, use "TODAY".

                IMPORTANT:
                - Return ONLY the JSON object, no other text
                - Use numbers for amounts, not strings

                IMPORTANT CURRENCY DETECTION:
                - Look for currency symbols: $, €, £, ¥, ₹, ₦, R, ₩, ₡, ₴, ₫, ₱, etc.
                - Look for currency codes: USD, EUR, GBP, JPY, INR, NGN, ZAR, KRW, CRC, UAH, VND, PHP, etc.
                - Look for currency names: "Dollar", "Euro", "Pound", "Yen", "Rupee", "Naira", "Dong", "Peso", etc.
                - Common currencies: USD, EUR, GBP, CAD, AUD, JPY, CNY, INR, MXN, BRL, ZAR, NGN, KES, GHS, VND, PHP, THB, SGD, MYR, IDR, etc.
                - Return the 3-letter ISO currency code (e.g., "USD" not "$", "EUR" not "€", "VND" not "₫")
                - If no currency is visible, analyze the merchant/location context to guess currency

                CURRENCY-SPECIFIC NUMBER FORMATTING:
                - For Vietnamese Dong (VND) receipts: Convert period-separated numbers to standard format
                  Examples: "60.000" → 60000, "1.234.567" → 1234567, "23.450.000" → 23450000
                - For VND amounts, periods are thousands separators, NOT decimal points
                - Return clean numbers without formatting: 60000 instead of "60.000"
                - If you see ₫ symbol or Vietnamese text, use VND currency code
                - Vietnamese examples: "60.000 ₫" = 60000, "1.234.567 VND" = 1234567

                ${categoryInstruction}

                Be accurate with numbers, dates, and especially CURRENCY detection. If unclear, use your best judgment and lower the confidence score.`
              },
              {
                type: 'image_url',
                image_url: {
                  url: `data:image/jpeg;base64,${base64Image}`
                }
              }
            ]
          }
        ],
        max_tokens: 1000,
        temperature: 0.1
      })
    });

    if (!openRouterResponse.ok) {
      const errorText = await openRouterResponse.text();
      logger.error('OpenRouter API error:', errorText);
      return res.status(500).json({ error: 'Receipt analysis failed' });
    }

    const openRouterData = await openRouterResponse.json() as any;
    const analysisText = openRouterData.choices[0]?.message?.content;
    
    if (!analysisText) {
      return res.status(500).json({ error: 'No analysis result received' });
    }

    // Parse the JSON response
    let analysisResult;
    try {
      // Extract JSON from the response (it might have additional text)
      const jsonMatch = analysisText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        analysisResult = JSON.parse(jsonMatch[0]);
        logger.info(`📅 AI returned date: "${analysisResult.date}" (raw from AI)`);
      } else {
        throw new Error('No JSON found in response');
      }
    } catch (parseError) {
      logger.error('Failed to parse analysis result:', parseError);
      return res.status(500).json({ error: 'Invalid analysis result format' });
    }

    // Enhanced date parsing that handles "TODAY" keyword
    if (analysisResult.date && analysisResult.date.toUpperCase() === 'TODAY') {
      // AI detected no date on receipt, use current date and time
      const todayDate = new Date().toISOString().split('T')[0];
      logger.info(`📅 AI returned "TODAY" - converting to: ${todayDate}`);
      analysisResult.date = todayDate;
    } else {
      logger.info(`📅 AI extracted actual date from receipt: "${analysisResult.date}"`);
    }

    // Validate and format the response
    const result = {
      merchant_name: analysisResult.merchant_name || 'Unknown Merchant',
      amount: Number(analysisResult.amount) || 0,
      currency: analysisResult.currency || 'USD',
      date: analysisResult.date || new Date().toISOString().split('T')[0],
      category: analysisResult.category || 'Other',
      items: Array.isArray(analysisResult.items) ? analysisResult.items : [],
      confidence: Number(analysisResult.confidence) || 0.5,
      processing_time: Date.now() - (req.startTime || Date.now())
    };

    logger.info(`Receipt analysis completed for user ${userId}: ${result.merchant_name} - $${result.amount}`);
    res.json(result);

  } catch (error) {
    logger.error(`❌ [${requestId}] Receipt analysis error:`, error);
    logger.error(`❌ [${requestId}] Error stack:`, error instanceof Error ? error.stack : 'No stack');
    res.status(500).json({ 
      error: 'Internal server error',
      message: 'Receipt analysis failed. Please try again.',
      requestId: requestId
    });
  }
});

// MARK: - App Configuration Endpoint

app.get('/api/app-config', verifyAuth, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user.uid;
    logger.info(`App config requested by user: ${userId}`);

    // Get RevenueCat API key from Firebase secrets
    const revenueCatKey = revenueCatApiKey.value()?.trim();
    
    if (!revenueCatKey) {
      logger.error('RevenueCat API key not configured');
      return res.status(500).json({ error: 'App configuration not available' });
    }

    // Return secure configuration
    const config = {
      revenuecat_api_key: revenueCatKey,
      features: {
        receipt_analysis: true,
        premium_analytics: true,
        cloud_sync: true,
        export_data: true
      },
      rate_limit: {
        receipts_per_hour: 20,
        receipts_per_day: 100
      }
    };

    res.json(config);

  } catch (error) {
    logger.error('App config error:', error);
    res.status(500).json({ error: 'Failed to load configuration' });
  }
});

// MARK: - Roast Generation Endpoint

app.post('/api/generate-roast', optionalAuth, async (req: AuthenticatedRequest, res: Response) => {
  try {
    // Use user ID if authenticated, otherwise use IP address for rate limiting
    const userId = req.user?.uid || req.ip || 'anonymous';
    const isAuthenticated = !!req.user;
    logger.info(`Roast generation requested by ${isAuthenticated ? 'authenticated user' : 'anonymous user'}: ${userId}`);

    // Rate limiting for roasts (more restrictive for unauthenticated)
    const rateLimit = isAuthenticated ? 50 : 10; // 50/hour for auth, 10/hour for anon
    if (!checkRateLimit(userId + '_roast', rateLimit, 3600000)) {
      return res.status(429).json({
        error: 'Rate limit exceeded',
        message: 'Too many roast requests. Please try again later.'
      });
    }

    const { amount, merchant, category, notes, lineItems, userName, currency } = req.body;

    if (!amount || !merchant) {
      return res.status(400).json({ error: 'Missing required fields: amount, merchant' });
    }

    // Determine language based on currency
    const isTaglish = currency === 'PHP';
    logger.info(`Roast language: ${isTaglish ? 'Taglish (PHP)' : 'English'}, currency: ${currency || 'not specified'}`);

    // Get OpenRouter API key from Firebase secrets
    const apiKey = openRouterApiKey.value()?.trim();

    if (!apiKey) {
      logger.error('OpenRouter API key not configured for roast');
      return res.status(500).json({ error: 'Roast service not available' });
    }

    // Build context string with optional notes and line items
    const contextParts = [amount + ` at ` + merchant + ` for ` + (category || `stuff`)];
    if (notes && notes.trim()) {
      contextParts.push(`(notes: ` + notes + `)`);
    }
    // Add line items for extra roasting context
    if (lineItems && Array.isArray(lineItems) && lineItems.length > 0) {
      if (lineItems.length > 5) {
        // Many items - summarize the receipt
        const topItems = lineItems.slice(0, 3).map((item: any) => {
          const name = item.name || item.description || 'item';
          return name;
        }).join(', ');
        contextParts.push(`(${lineItems.length} items including: ` + topItems + `)`);
      } else {
        // Few items - list them all
        const itemsSummary = lineItems.map((item: any) => {
          const name = item.name || item.description || 'item';
          const qty = item.quantity || 1;
          return qty > 1 ? `${qty}x ${name}` : name;
        }).join(', ');
        contextParts.push(`(bought: ` + itemsSummary + `)`);
      }
    }
    const purchaseContext = contextParts.join(` `);

    // Determine language instruction based on currency
    const getLanguageInstruction = (curr: string | undefined): string => {
      switch (curr) {
        case 'PHP':
          return `LANGUAGE: Write in TAGLISH (natural mix of Tagalog and English, like how Filipinos actually talk). Example: "₱500 sa Grab, ayaw mo na talaga maglakad ano."`;
        case 'JPY':
          return `LANGUAGE: Write in casual Japanese (日本語). Example: "¥500でタクシー？歩けば無料なのに。"`;
        case 'KRW':
          return `LANGUAGE: Write in casual Korean (한국어). Example: "₩5000 커피? 물은 공짜인데."`;
        case 'CNY':
          return `LANGUAGE: Write in casual Mandarin Chinese (中文). Example: "¥50块打车？腿是装饰品吗？"`;
        case 'THB':
          return `LANGUAGE: Write in casual Thai (ภาษาไทย). Example: "฿500 ค่าแท็กซี่? ขาไว้ทำไม"`;
        case 'VND':
          return `LANGUAGE: Write in casual Vietnamese (Tiếng Việt). Example: "500k đi Grab? Chân để làm cảnh à?"`;
        case 'IDR':
          return `LANGUAGE: Write in casual Indonesian (Bahasa Indonesia). Example: "Rp50rb naik ojol? Kaki cuma pajangan ya?"`;
        case 'MYR':
          return `LANGUAGE: Write in Manglish (Malaysian English mix). Example: "RM50 for Grab lah, walking is so last season."`;
        case 'EUR':
          return `LANGUAGE: Write in English. Example: "€50 on Uber, walking is apparently beneath us now."`;
        case 'GBP':
          return `LANGUAGE: Write in British English. Example: "£50 on a cab? Legs are just for show then, innit."`;
        default:
          return `LANGUAGE: Write in English. Example: "$50 on Uber, oh so we're just not walking anymore."`;
      }
    };

    const languageInstruction = getLanguageInstruction(currency);

    // Call OpenRouter API with deadpan roast prompt
    logger.info('Generating roast via OpenRouter...');
    const openRouterResponse = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://cashmonki.app',
        'X-Title': 'CashMonki Receipt Roaster'
      },
      body: JSON.stringify({
        model: 'openai/gpt-4o',
        messages: [
          {
            role: 'system',
            content: `Sarcastic roast about the SPECIFIC purchase. ONE sentence, <15 words.

MUST be relevant to what they bought. Deadpool energy.

${languageInstruction}

NEVER: quotes, brackets, Marvel refs, "bold choice", random nonsense unrelated to purchase.
Output: ["roast1","roast2","roast3"]`
          },
          {
            role: 'user',
            content: `Roast: ${purchaseContext}`
          }
        ],
        max_tokens: 120,
        temperature: 0.9
      })
    });

    if (!openRouterResponse.ok) {
      const errorText = await openRouterResponse.text();
      logger.error('OpenRouter roast API error:', errorText);
      return res.status(500).json({ error: 'Roast generation failed' });
    }

    const openRouterData = await openRouterResponse.json() as any;
    const roastContent = openRouterData.choices[0]?.message?.content?.trim();

    if (!roastContent) {
      return res.status(500).json({ error: 'No roast generated' });
    }

    // Parse JSON array and pick a random roast
    let roastText: string;
    try {
      const jsonMatch = roastContent.match(/\[[\s\S]*\]/);
      if (jsonMatch) {
        const roasts = JSON.parse(jsonMatch[0]) as string[];

        // Filter out only truly problematic roasts (keep questions, allow 2 sentences)
        const forbiddenWords = ['self-care', 'self-respect', 'intervention', 'crisis', 'sabotage', 'existential', 'therapy', 'nowhere', 'life goes', 'taste buds', 'identity'];
        const validRoasts = roasts
          .map((r: string) => r.trim())
          .filter((r: string) => {
            const hasForbiddenWord = forbiddenWords.some(word => r.toLowerCase().includes(word));
            return r.length > 20 && r.length < 250 && !hasForbiddenWord;
          });

        if (validRoasts.length > 0) {
          roastText = validRoasts[Math.floor(Math.random() * validRoasts.length)];
        } else {
          // Use first roast if no valid ones
          roastText = roasts[0]?.trim() || roastContent;
        }
      } else {
        // Fallback to raw text if not JSON array
        roastText = roastContent;
      }
    } catch {
      // Fallback to raw text if parsing fails
      roastText = roastContent;
    }

    // Clean up the roast - remove quotes, brackets, question marks
    const finalRoast = roastText
      .replace(/^[\["']|[\]"']$/g, '')  // Remove leading/trailing quotes and brackets
      .replace(/^\[|\]$/g, '')  // Extra bracket removal
      .replace(/\?/g, '.')
      .trim();

    logger.info(`Roast generated for user ${userId}: ${finalRoast.substring(0, 50)}...`);
    res.json({ roast: finalRoast });

  } catch (error) {
    logger.error('Roast generation error:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to generate roast. Please try again.'
    });
  }
});

// MARK: - Health Check Endpoint

app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// Error handling middleware
app.use((error: any, req: any, res: any, next: any) => {
  logger.error('Unhandled error:', error);
  res.status(500).json({
    error: 'Internal server error',
    message: error.message
  });
});

// Export the Express app as a Firebase Function
export const api = onRequest({
  region: 'us-central1',
  memory: '1GiB',
  timeoutSeconds: 60,
  maxInstances: 10,
  secrets: [openRouterApiKey, revenueCatApiKey]
}, app);