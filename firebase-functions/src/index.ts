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

// Middleware to verify Firebase Auth token
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
    
    categoriesText += "For subcategories (items in parentheses), use the specific subcategory name if it's a better match.";
    
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

app.post('/api/analyze-receipt', verifyAuth, async (req: AuthenticatedRequest, res: Response) => {
  const requestId = Math.random().toString(36).substr(2, 9);
  
  // EMERGENCY DEBUG: Use console.log to force output
  console.log(`🚨 [${requestId}] Receipt analysis ENTRY POINT`);
  console.log(`🚨 [${requestId}] Headers:`, Object.keys(req.headers));
  console.log(`🚨 [${requestId}] Content-Type:`, req.headers['content-type']);
  console.log(`🚨 [${requestId}] Body type:`, typeof req.body);
  console.log(`🚨 [${requestId}] Body:`, req.body ? Object.keys(req.body) : 'NULL BODY');
  
  logger.error(`🚨 EMERGENCY DEBUG [${requestId}] Receipt analysis started`);
  
  try {
    const userId = req.user.uid;
    logger.error(`🚨 EMERGENCY DEBUG Receipt analysis requested by user: ${userId}`);

    // Rate limiting
    if (!checkRateLimit(userId, 20, 3600000)) { // 20 requests per hour
      return res.status(429).json({ 
        error: 'Rate limit exceeded',
        message: 'Too many receipt analysis requests. Please try again in an hour.'
      });
    }
    
    // Fetch user's categories for personalized AI analysis
    const userCategoriesText = await fetchUserCategories(userId);

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
                text: `Analyze this receipt image and extract the following information in JSON format:
                {
                  "merchant_name": "business name",
                  "amount": 0.00,
                  "date": "YYYY-MM-DD",
                  "category": "category name",
                  "items": [
                    {"name": "item name", "price": 0.00, "quantity": 1}
                  ],
                  "confidence": 0.95
                }
                
                ${userCategoriesText}
                
                Be accurate with numbers and dates. If unclear, use your best judgment and lower the confidence score.`
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
      } else {
        throw new Error('No JSON found in response');
      }
    } catch (parseError) {
      logger.error('Failed to parse analysis result:', parseError);
      return res.status(500).json({ error: 'Invalid analysis result format' });
    }

    // Validate and format the response
    const result = {
      merchant_name: analysisResult.merchant_name || 'Unknown Merchant',
      amount: Number(analysisResult.amount) || 0,
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