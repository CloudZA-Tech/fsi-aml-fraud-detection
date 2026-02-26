import { NextResponse } from 'next/server';
import { getToken } from 'next-auth/jwt';

export async function middleware(request) {
  const { pathname } = request.nextUrl;

  // allow next-auth endpoints and other static assets to pass through
  if (
    pathname.startsWith('/api/auth') ||
    pathname.startsWith('/_next') ||
    pathname === '/favicon.ico' ||
    pathname.match(/\.(png|jpg|svg)$/)
  ) {
    return NextResponse.next();
  }

  // attempt to read a valid session token
  const token = await getToken({ req: request, secret: process.env.NEXTAUTH_SECRET });
  console.debug('[middleware] NEXTAUTH_URL', process.env.NEXTAUTH_URL,
                'NEXTAUTH_SECRET', !!process.env.NEXTAUTH_SECRET,
                'cookies', request.headers.get('cookie'),
                'token', token);

  if (!token) {
    // build signin url including callback so we return to the original page
    const signInUrl = new URL('/api/auth/signin', request.url);
    signInUrl.searchParams.set('callbackUrl', request.url);
    console.debug('[middleware] no token, redirecting to', signInUrl.href);
    return NextResponse.redirect(signInUrl);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico|.*\\.png|.*\\.jpg|.*\\.svg).*)'],
};
