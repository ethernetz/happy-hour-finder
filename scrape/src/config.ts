import dotenv from 'dotenv';

dotenv.config({ path: '.env' });

export const OPENAI_API_KEY = process.env.OPENAI_API_KEY as string;
