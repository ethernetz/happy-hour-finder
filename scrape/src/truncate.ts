import { getEncoding } from 'js-tiktoken';
export const truncate = (inputString: string) => {
	// Step 1: Get the encoder for a particular model
	const encoder = getEncoding('cl100k_base');

	// Step 2: Tokenize the input string
	const tokens = encoder.encode(inputString);

	// Step 3: Truncate the token list if it's too long
	const truncatedTokens = tokens.length > 3700 ? tokens.slice(0, 3700) : tokens;

	// Step 4: Decode the truncated token list back into a string
	const truncatedString = encoder.decode(truncatedTokens);

	// Step 5: Return the truncated string
	return truncatedString;
};
