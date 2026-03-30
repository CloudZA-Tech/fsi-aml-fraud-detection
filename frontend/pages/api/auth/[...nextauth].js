import NextAuth from "next-auth";
import CognitoProvider from "next-auth/providers/cognito";

export const authOptions = {
  providers: [
    CognitoProvider({
      clientId: process.env.COGNITO_CLIENT_ID,
      clientSecret: process.env.COGNITO_CLIENT_SECRET,
      issuer: process.env.COGNITO_ISSUER,
    }),
  ],
  secret: process.env.NEXTAUTH_SECRET,
  debug: true,
  // Ensure NextAuth uses the correct URL
  url: process.env.NEXTAUTH_URL,
  // Use secure cookies for HTTPS
  useSecureCookies: process.env.NEXTAUTH_URL?.startsWith('https://'),
  pages: {
    signIn: '/auth/signin',
    error: '/auth/signin', // Redirect errors to sign-in page with error query param
  },
  logger: {
    error(code, metadata) {
      console.error('[NextAuth Error]', code, metadata);
    },
    warn(code) {
      console.warn('[NextAuth Warn]', code);
    },
    debug(code, metadata) {
      console.log('[NextAuth Debug]', code, metadata);
    }
  },
};

export default NextAuth(authOptions);
