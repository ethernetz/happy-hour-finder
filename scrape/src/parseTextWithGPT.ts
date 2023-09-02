import OpenAI from 'openai';
import { truncate } from './truncate.js';
import { openai } from './config.js';
import { HappyHour } from './types.js';

const functions: OpenAI.Chat.Completions.CompletionCreateParams.Function[] = [
	{
		name: 'logHappyHourDealIntoDatabase',
		description: `
			Logs an array of happy hour deals into the database. 
			Each object in the array represents a specific day with its corresponding start time, end time, and deals. 
			The "day" must be one of the following lowercase strings: "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday". 
			The "startTime" and "endTime" must be in 24-hour format (e.g., 4pm is "16:00", 8:30pm is "20:30").
			The "deal" is a description of the happy hour special
			Examples for how a "deal" should look like:
			- "$5 beers, $6 wines, $7 cocktails",
			- "$7 draft selections, $10 house spirits, $11 select wines",
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

export async function parseTextWithGPT(websiteText: string): Promise<HappyHour[] | null> {
	const truncatedWebsiteText = truncate(websiteText);
	const response = await openai.chat.completions.create({
		messages: [
			{
				role: 'user',
				content: `
					Your primary objective is to parse the following website text log the happy hour deal into the database using the logHappyHourDealIntoDatabase method.
					Do not describe the action; perform it.
					If there is no mention of a happy hour or you're uncertain of the hours, do not log the happy hour into the database.

					Important: Fabricating details is unacceptable. Only invoke 'logHappyHourDealIntoDatabase' if the website text explicitly mentions a happy hour.

					Information about the logHappyHourDealIntoDatabase method:
					Each object in the array represents a specific day with its corresponding start time, end time, and deals. 
					The "day" must be one of the following lowercase strings: "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday". 
					The "startTime" and "endTime" must be in 24-hour format (e.g., 4pm is "16:00", 8:30pm is "20:30").
					The "deal" is a description of the happy hour special
					Examples for how a "deal" should look like:
					- "$5 beers, $6 wines, $7 cocktails",
					- "$7 draft selections, $10 house spirits, $11 select wines",
					- "Deals on frozen margaritas, classic cocktails, beer, and food",
					- "$11 cocktails, $2 off draft beer, 18$ carafes of house wine, $9 well",
					- "Unknown",
					- "Two for one drinks",
					- "A dozen oysters for $18, $12 cocktails, $5 bottles & cans, $6 all draft pints, $12 wine", 
					- "$8 wings, $5 mac n' cheese, $20 margarita pitchers, and more",
					- "$5 drinks",

					Below is the text data extracted from the website:

					${truncatedWebsiteText}

					Remember: Fabricating details is unacceptable. Only invoke 'logHappyHourDealIntoDatabase' if the website text explicitly mentions a happy hour.
					It is critical that you know the correct hours of the happy hour if you are going to log it into the database.
					If hours of the happy hour are known, but the deal is not, still log the hours into the database.
					`,
			},
		],
		model: 'gpt-4',
		functions: functions,
	});

	if (response?.choices[0]?.message?.function_call?.name === 'logHappyHourDealIntoDatabase') {
		const functionArgsJSON = JSON.parse(response.choices[0].message.function_call.arguments);
		return functionArgsJSON.happyHours;
	}

	return null;
}
