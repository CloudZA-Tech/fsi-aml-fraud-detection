import { NextResponse } from 'next/server';
import { getToken } from 'next-auth/jwt';

export async function middleware(request) {
  const { pathname } = request.nextUrl;

  // allow next-auth endpoints, health checks, and other static assets to pass through
  if (
    pathname.startsWith('/api/auth') ||
    pathname.startsWith('/auth/signin') ||
    pathname === '/api/health' ||
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
    // Use NEXTAUTH_URL as base URL to avoid internal ECS IP in callback
    const baseUrl = process.env.NEXTAUTH_URL || request.nextUrl.origin;
    const callbackUrl = `${baseUrl}${pathname}${request.nextUrl.search}`;
    
    // build signin url including callback so we return to the original page
    const signInUrl = new URL('/auth/signin', baseUrl);
    signInUrl.searchParams.set('callbackUrl', callbackUrl);
    console.debug('[middleware] no token, redirecting to', signInUrl.href);
    return NextResponse.redirect(signInUrl);
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    /*
     * Match all request paths except:
     * - /api/auth/* (NextAuth routes)
     * - /api/health (Health check endpoint)
     * - /_next/static (static files)
     * - /_next/image (image optimization)
     * - /favicon.ico, /robots.txt (metadata files)
     * - /*.png, /*.jpg, /*.svg (image files)
     */
    '/((?!api/auth|api/health|_next/static|_next/image|favicon.ico|robots.txt|.*\\.png|.*\\.jpg|.*\\.svg).*)',
  ],
};
