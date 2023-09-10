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

type CurrentLocation = {
	latitude: number;
	longitude: number;
};

// Specify the secret name in runWith parameter
export const helloWorld = functions
	.runWith({ secrets: ['MONGO_DB_CONNECTION_STRING'] })
	.https.onCall(async ({ latitude, longitude }: CurrentLocation, context) => {
		functions.logger.log('Current location:', latitude, longitude);
		try {
			const spots = (await getClient()).db('happyHourDB').collection('spots');
			const result = await spots
				.find({
					coordinates: {
						$near: {
							$geometry: { type: 'Point', coordinates: [longitude, latitude] },
							$maxDistance: 1000,
						},
					},
				})
				.toArray();

			functions.logger.log('Found spots:', result);

			return { message: 'Hello from Firebase!', data: [] };
		} catch (error) {
			functions.logger.error('Error occurred:', error);
			throw new functions.https.HttpsError('internal', 'Internal Server Error');
		}
	});
