import * as functions from 'firebase-functions';
import { MongoClient } from 'mongodb';

let client: MongoClient | null;

const getClient = async () => {
	const mongoDbConnectionString = process.env.MONGO_DB_CONNECTION_STRING;
	if (!mongoDbConnectionString)
		throw new functions.https.HttpsError('internal', 'Could not find MongoDB connection string');
	if (!client) {
		const mClient = new MongoClient(mongoDbConnectionString, {});
		client = await mClient.connect();
		functions.logger.log('Connected to MongoDB');
	} else {
		functions.logger.log('Using existing MongoDB connection');
	}
	return client;
};

// Specify the secret name in runWith parameter
export const helloWorld = functions
	.runWith({ secrets: ['MONGO_DB_CONNECTION_STRING'] })
	.https.onCall(async (data, context) => {
		try {
			const db = (await getClient()).db('happyHourDB');
			const result = await db.collection('spots').findOne({});
			// functions.logger.log('Result:', result);
			return { message: 'Hello from Firebase!', data: result };
		} catch (error) {
			functions.logger.error('Error occurred:', error);
			throw new functions.https.HttpsError('internal', 'Internal Server Error');
		}
	});
