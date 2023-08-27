import { URL } from 'url';
import OpenAI from 'openai';
import { openai, websiteTextDB } from './config';
import { truncate } from './truncate';
import { collectTextFromDomain } from './collectTextFromDomain';

const urls = [
	'https://www.phebesnyc.com/',
	'https://www.ordercacioevino.com/',
	'https://www.coopersnyc.com/',
	'https://www.whiteoakny.com/',
	'https://www.thegraymarenyc.com/',
	'https://www.sweetandvicious.com/',
];

const functions: OpenAI.Chat.Completions.CompletionCreateParams.Function[] = [
	{
		name: 'logHappyHourDealIntoDatabase',
		description: `
			Logs an array of happy hour deals into the database. 
			Each object in the array represents a specific day with its corresponding start time, end time, and deals. 
			The "day" must be a lowercase string (e.g., "monday"), the "startTime" and "endTime" must be in 24-hour format (e.g., "16:00"), and the "deal" is a description of the happy hour special (e.g., "50% off drinks").`,
		parameters: {
			type: 'object',
			properties: {
				happyHours: {
					type: 'array',
					items: {
						type: 'object',
						properties: {
							day: { type: 'string' },
							startTime: { type: 'string' },
							endTime: { type: 'string' },
							deal: { type: 'string' },
						},
						required: ['day', 'startTime', 'endTime', 'deal'],
					},
				},
			},
			required: ['happyHours'],
		},
	},
];

async function processUrls(urls: string[]) {
	for (const url of urls) {
		let websiteText: string | undefined;
		try {
			websiteText = await websiteTextDB.get(url);
			// eslint-disable-next-line @typescript-eslint/no-explicit-any
		} catch (err: any) {
			if (err.code === 'LEVEL_NOT_FOUND') {
				websiteText = await collectTextFromDomain(new URL(url));
				await websiteTextDB.put(url, websiteText);
			}
		}

		if (!websiteText) console.log('no website text found for', url);
		if (!websiteText) continue;

		console.log('making gpt request for', url);
		const response = await openai.chat.completions.create({
			messages: [
				{
					role: 'user',
					content: `
					Your primary objective is to parse the following website text log the happy hour deal into the database using the logHappyHourDealIntoDatabase method.
					If there is no mention of a happy hour or you're uncertain, do not log the happy hour into the database.

					Important: Fabricating details is unacceptable. Only invoke 'logHappyHourDealIntoDatabase' if the website text explicitly mentions a happy hour.

					Below is the text data extracted from the website:

					${truncate(websiteText)}
					`,
				},
			],
			model: 'gpt-4',
			functions: functions,
		});
		const responseMessage = response.choices[0].message;
		if (responseMessage.function_call) {
			console.log(url, responseMessage.function_call.arguments);
		} else {
			console.log(url, 'fake', responseMessage);
		}
	}
}

processUrls(urls);
