import { getRestuarants } from '$db/restuarants';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async () => {
	const restuarants = await getRestuarants();
	restuarants.map((restaurant) => {
		restaurant._id = restaurant._id.toString();
		return restaurant;
	});
	return { restuarants };
};
