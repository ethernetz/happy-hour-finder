import { MongoClient } from 'mongodb';
import { MONGODB_URI } from '../../config';

if (!MONGODB_URI) throw new Error('MONGODB_URI is not defined');
const client = new MongoClient(MONGODB_URI);
console.log('Connecting to MongoDB...');
const clientPromise = client.connect().finally(() => {
	console.log('Connected to MongoDB!');
});

export default clientPromise;
