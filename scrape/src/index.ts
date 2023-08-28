import { URL } from 'url';
import OpenAI from 'openai';
import { openai, websiteTextDB } from './config';
import { truncate } from './truncate';
import { collectTextFromDomain } from './collectTextFromDomain';

const urls = [
	// 'https://www.phebesnyc.com/',
	// 'https://www.ordercacioevino.com/',
	// 'https://www.coopersnyc.com/',
	// 'https://www.whiteoakny.com/',
	// 'https://www.thegraymarenyc.com/',
	// 'https://www.sweetandvicious.com/',
	// 'http://www.buabar.com/',
	// 'https://www.upstatenyc.com/',
	// 'https://www.tendegreesbar.com/',
	// 'https://www.goodnightsonnynyc.com/',
	// 'https://www.misterparadisenyc.com/',
	// 'https://www.a10kitchen.com/',
	// 'https://www.tilebarnyc.com/',
	// 'https://www.thecopperstillnyc.com/',
	// 'https://the-scratcher.business.site/',
	// 'https://www.downtownsocialnyc.com/',
	// 'https://www.bonnievee.com/',
	// 'http://yucabarnyc.com/',
	// 'https://www.loreleynyc.com/',
	// 'https://www.99centsfreshpizzanyc.com/',
	// 'https://www.verlainenyc.com/',
	// 'http://www.tenbellsnyc.com/',
	// 'http://www.blackcrescentnyc.com/',
	// 'https://www.foolsgoldnyc.com/',
	// 'https://169barnyc.com/',
	// 'https://luckyjacksnyc.com/',
	'https://nursebettie.com/',
];

const functions: OpenAI.Chat.Completions.CompletionCreateParams.Function[] = [
	{
		name: 'logHappyHourDealIntoDatabase',
		description: `
			Logs an array of happy hour deals into the database. 
			Each object in the array represents a specific day with its corresponding start time, end time, and deals. 
			The "day" must be one of the following lowercase strings: "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday". 
			The "startTime" and "endTime" must be in 24-hour format (e.g., "16:00"). 
			The "deal" is a description of the happy hour special
			Examples for how a "deal" should look like:
			- "$5 beers, $6 wines, $7 cocktails",
			- "$7 draft selections, $10 house spirits, $11 select wines",
			- "$9 cocktails, $7 beers, $9 wines",
			- "Deals on frozen margaritas, classic cocktails, beer, and food",
			- "$11 cocktails, $2 off draft beer, 18$ carafes of house wine, $9 well",
			- "Unknown",
			- "Two for one drinks",
			- "A dozen oysters for $18, $12 cocktails, $5 bottles & cans, $6 all draft pints, $12 wine", 
			- "$8 wings, $5 mac n' cheese, $20 margarita pitchers, and more",
			- "$5 drinks",
			`,
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
						required: ['day', 'startTime', 'endTime'],
					},
				},
			},
			required: ['happyHours'],
		},
	},
];

async function promptGPT(websiteText: string) {
	return await openai.chat.completions.create({
		messages: [
			{
				role: 'user',
				content: `
					Your primary objective is to parse the following website text log the happy hour deal into the database using the logHappyHourDealIntoDatabase method.
					Do not describe the action; perform it.
					If there is no mention of a happy hour or you're uncertain of the hours, do not log the happy hour into the database.

					Important: Fabricating details is unacceptable. Only invoke 'logHappyHourDealIntoDatabase' if the website text explicitly mentions a happy hour.

					Examples for how a "deal" should look like:
					- "$5 beers, $6 wines, $7 cocktails",
					- "$7 draft selections, $10 house spirits, $11 select wines",
					- "$9 cocktails, $7 beers, $9 wines",
					- "$6 draft beers, $10 classic cocktails, $8 wines, $6 appetizers",
					- "Deals on frozen margaritas, classic cocktails, beer, and food",
					- "$11 cocktails, $2 off draft beer, 18$ carafes of house wine, $9 well",
					- "Unknown",
					- "Two for one drinks",
					- "A dozen oysters for $18, $12 cocktails, $5 bottles & cans, $6 all draft pints, $12 wine", 
					- "$8 wings, $5 mac n' cheese, $20 margarita pitchers, and more",
					- "$5 drinks",

					Below is the text data extracted from the website:

					${truncate(websiteText)}

					Remember: Fabricating details is unacceptable. Only invoke 'logHappyHourDealIntoDatabase' if the website text explicitly mentions a happy hour.
					It is critical that you know the correct hours of the happy hour if you are going to log it into the database.
					If hours of the happy hour are known, but the deal is not, still log the hours into the database.
					`,
			},
		],
		model: 'gpt-4',
		functions: functions,
	});
}

async function processUrls(urls: string[]) {
	for (const url of urls) {
		// await websiteTextDB.del(url);
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

		console.log(websiteText);

		console.log('making gpt request for', url);
		const response = await promptGPT(websiteText);
		const responseMessage = response.choices[0].message;
		if (responseMessage.function_call) {
			console.log(url, responseMessage.function_call.arguments);
		} else {
			console.log(url, 'fake', responseMessage);
		}
	}
}

processUrls(urls);
