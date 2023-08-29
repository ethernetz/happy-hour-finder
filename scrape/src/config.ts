import dotenv from 'dotenv';
import { Level } from 'level';
import OpenAI from 'openai';
import { ImageAnnotatorClient } from '@google-cloud/vision';
import { dirname, resolve } from 'path';
import { fileURLToPath } from 'url';

dotenv.config({ path: '.env' });

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
