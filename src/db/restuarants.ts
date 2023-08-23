import clientPromise from '$db/mongo';

export const getRestuarants = async () => {
	const client = await clientPromise;
	const tutorial = client.db('sample_restaurants');
	const collection = tutorial.collection('restaurants');
	return await collection
		.find({})
		.project({
			grades: 0,
			borough: 0,
			restaurantId: 0
		})
		.limit(10)
		.toArray();
};
