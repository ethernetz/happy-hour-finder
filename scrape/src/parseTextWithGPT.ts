import OpenAI from 'openai';
import { truncate } from './truncate.js';
import { openai } from './config.js';
import { HappyHour } from './types.js';

const description =
	'Logs an array of happy hour deals into the database. ' +
	'Each object in the array represents a specific day with its corresponding start time, end time, and deals. ' +
	'The "day" must be one of the following lowercase strings: "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday". ' +
	'The "startTime" and "endTime" must be in 24-hour format.\n' +
	'Examples for how a "time" should look like:\n' +
	'- 8:30pm is "20:30"\n' +
	'- 11am is "11:00"\n' +
	'- "All day/night" is "00:00" to "23:59"\n' +
	'The "deal" is a description of the happy hour special\n' +
	'Examples for how a "deal" should look like:\n' +
	'- "$5 beers, $6 wines, $7 cocktails"\n' +
	'- "Deals on frozen margaritas, classic cocktails, beer, and food"\n' +
	'- "Unknown"\n' +
	'- "Two for one drinks"\n' +
	'The "crossesMidnight" is a boolean flag indicating if the happy hour crosses midnight into the next day.\n' +
	'Examples for when "crossesMidnight" should be true or false:\n' +
	'- If the happy hour reads "10pm to 4am", "crossesMidnight" should be true\n' +
	'- If the happy hour reads "5pm to 7pm", "crossesMidnight" should be false';

const functions: OpenAI.Chat.Completions.CompletionCreateParams.Function[] = [
	{
		name: 'logHappyHourDealIntoDatabase',
		description,
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
							crossesMidnight: { type: 'boolean' },
							deal: { type: 'string' },
						},
						required: ['day', 'startTime', 'endTime', 'crossesMidnight'],
					},
				},
			},
			required: ['happyHours'],
		},
	},
];

export async function parseTextWithGPT(websiteText: string): Promise<HappyHour[] | null> {
	const truncatedWebsiteText = truncate(websiteText);
	const content =
		'Your primary objective is to parse the following website text log the happy hour deal into the database using the logHappyHourDealIntoDatabase method. ' +
		'Do not describe the action; perform it. ' +
		"If there is no mention of a happy hour or you're uncertain of the hours, do not log the happy hour into the database.\n" +
		"Important: Fabricating details is unacceptable. Only invoke 'logHappyHourDealIntoDatabase' if the website text explicitly mentions a happy hour.\n" +
		'Information about the logHappyHourDealIntoDatabase method:\n' +
		'Each object in the array represents a specific day with its corresponding start time, end time, and deals. ' +
		'The "day" must be one of the following lowercase strings: "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday". ' +
		'The "startTime" and "endTime" must be in 24-hour format.\n' +
		'Examples for how a "time" should look like:\n' +
		'- 4pm is "16:00"\n' +
		'- 8:30pm is "20:30"\n' +
		'- 11am is "11:00"\n' +
		'- "All day/night" is "00:00" to "23:59"\n' +
		'The "deal" is a description of the happy hour special\n' +
		'Examples for how a "deal" should look like:\n' +
		'- "$5 beers, $6 wines, $7 cocktails"\n' +
		'- "Deals on frozen margaritas, classic cocktails, beer, and food"\n' +
		'- "Unknown"\n' +
		'- "Two for one drinks"\n' +
		'- "$8 wings, $5 mac n\' cheese, $20 margarita pitchers, and more"\n' +
		'- "$5 drinks"\n' +
		'The "crossesMidnight" is a boolean flag indicating if the happy hour crosses midnight into the next day.\n' +
		'Examples for when "crossesMidnight" should be true or false:\n' +
		'- If the happy hour reads "10pm to 4am", "crossesMidnight" should be true.\n' +
		'- If the happy hour reads "5pm to 7pm", "crossesMidnight" should be false.\n' +
		'Below is the text data extracted from the website:\n' +
		`${truncatedWebsiteText}\n` +
		"Remember: Fabricating details is unacceptable. Only invoke 'logHappyHourDealIntoDatabase' if the website text explicitly mentions a happy hour. " +
		'It is critical that you know the correct hours of the happy hour if you are going to log it into the database. ' +
		'If hours of the happy hour are known, but the deal is not, still log the hours into the database.';

	const response = await openai.chat.completions.create({
		messages: [
			{
				role: 'user',
				content,
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
