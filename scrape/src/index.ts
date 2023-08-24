import OpenAI from 'openai';
import { OPENAI_API_KEY } from './config';

if (!OPENAI_API_KEY) throw new Error('OPENAI_API_KEY not set');

const openai = new OpenAI({
	apiKey: OPENAI_API_KEY
});

async function main() {
	const completion = await openai.chat.completions.create({
		messages: [{ role: 'user', content: 'Say this is a test' }],
		model: 'gpt-3.5-turbo'
	});

	console.log(completion.choices);
}

main();
