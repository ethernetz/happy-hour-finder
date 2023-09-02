import dotenv from 'dotenv';
import { Level } from 'level';
import OpenAI from 'openai';
import { ImageAnnotatorClient } from '@google-cloud/vision';
import { Storage } from '@google-cloud/storage';
import { dirname, resolve } from 'path';
import { fileURLToPath } from 'url';
import { MongoClient } from 'mongodb';

dotenv.config({ path: '.env.local' });

export const MONGODB_URI = process.env.MONGODB_URI as string;
if (!MONGODB_URI) throw new Error('MONGODB_URI is not defined');
const client = new MongoClient(MONGODB_URI);
console.log('Connecting to MongoDB...');
const mongoClientPromise = client.connect().finally(() => {
	console.log('Connected to MongoDB!');
});

export default mongoClientPromise;

const OPENAI_API_KEY = process.env.OPENAI_API_KEY as string;
if (!OPENAI_API_KEY) throw new Error('OPENAI_API_KEY not set');
export const openai = new OpenAI({
	apiKey: OPENAI_API_KEY,
});

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const websiteTextPath = resolve(__dirname, '..', 'website-text'); // Go up one level to project root
export const websiteTextDB = new Level(websiteTextPath, { valueEncoding: 'json' });

export const imageAnnotatorClient = new ImageAnnotatorClient();
export const storage = new Storage();
