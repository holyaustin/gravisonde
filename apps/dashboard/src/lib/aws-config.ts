// Shared AWS client settings.
// Vercel reserves AWS_SECRET_ACCESS_KEY, AWS_REGION, etc. → use GRAVI_* instead.
// Local (Docker + LocalStack): fall back to SDK credential chain.
// Vercel: GRAVI_* vars supply region + credentials.

const region =
  process.env.GRAVI_AWS_REGION ??
  process.env.AWS_REGION ??
  process.env.AWS_DEFAULT_REGION ??
  "us-east-1";

const accessKeyId = process.env.GRAVI_AWS_ACCESS_KEY_ID;
const secretAccessKey = process.env.GRAVI_AWS_SECRET_ACCESS_KEY;

export const awsClientConfig = {
  region,
  ...(process.env.AWS_ENDPOINT_URL ? { endpoint: process.env.AWS_ENDPOINT_URL } : {}),
  ...(accessKeyId && secretAccessKey
    ? { credentials: { accessKeyId, secretAccessKey } }
    : {}),
};