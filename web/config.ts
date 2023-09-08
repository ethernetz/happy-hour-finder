import dotenv from 'dotenv';

dotenv.config({ path: '.env.local' });

export const MONGODB_URI = process.env.MONGODB_URI as string;
export const VERCEL_ENV = process.env.VERCEL_ENV as string;
