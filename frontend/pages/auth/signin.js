import { signIn } from 'next-auth/react';
import { useRouter } from 'next/router';
import { useState } from 'react';
import Card from '@leafygreen-ui/card';
import Button from '@leafygreen-ui/button';
import { H1, Body, Description } from '@leafygreen-ui/typography';
import Icon from '@leafygreen-ui/icon';
import Banner from '@leafygreen-ui/banner';
import { palette } from '@leafygreen-ui/palette';

export default function SignIn() {
  const router = useRouter();
  const { callbackUrl, error } = router.query;
  const [isLoading, setIsLoading] = useState(false);

  const handleSignIn = async () => {
    setIsLoading(true);
    try {
      console.log('[SignIn] Initiating Cognito sign-in with callbackUrl:', callbackUrl || '/');
      console.log('[SignIn] NEXTAUTH_URL should be:', window.location.origin);
      
      await signIn('cognito', {
        callbackUrl: callbackUrl || '/',
        redirect: true,
      });
    } catch (error) {
      console.error('[SignIn] Sign in error:', error);
      setIsLoading(false);
    }
  };

  const getErrorMessage = (error) => {
    switch (error) {
      case 'OAuthSignin':
        return 'Error constructing authorization URL. Please contact support.';
      case 'OAuthCallback':
        return 'Error handling OAuth callback. Please try again.';
      case 'OAuthCreateAccount':
        return 'Could not create user account. Please contact support.';
      case 'EmailCreateAccount':
        return 'Could not create user account. Please contact support.';
      case 'Callback':
        return 'Error in callback handler. Please try again.';
      case 'OAuthAccountNotLinked':
        return 'Account already exists with different provider. Please use your original sign-in method.';
      case 'EmailSignin':
        return 'Check your email for the sign-in link.';
      case 'CredentialsSignin':
        return 'Sign in failed. Check your credentials.';
      case 'SessionRequired':
        return 'Please sign in to access this page.';
      default:
        return 'An error occurred during sign in. Please try again.';
    }
  };

  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      background: `linear-gradient(135deg, ${palette.green.dark3} 0%, ${palette.green.dark2} 50%, ${palette.green.dark1} 100%)`,
      padding: '20px'
    }}>
      <Card
        style={{
          maxWidth: '480px',
          width: '100%',
          padding: '48px',
          textAlign: 'center',
          boxShadow: '0 20px 60px rgba(0, 0, 0, 0.3)',
        }}
      >
        {/* MongoDB Logo */}
        <div style={{ marginBottom: '32px' }}>
          <svg
            width="120"
            height="32"
            viewBox="0 0 120 32"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
            style={{ margin: '0 auto' }}
          >
            <path
              d="M16.5 0C16.5 0 14.5 1.5 14.5 4.5C14.5 7.5 16.5 9 16.5 9C16.5 9 18.5 7.5 18.5 4.5C18.5 1.5 16.5 0 16.5 0Z"
              fill="#00ED64"
            />
            <path
              d="M16.5 9C16.5 9 11 11 11 16C11 21 16.5 24 16.5 24C16.5 24 22 21 22 16C22 11 16.5 9 16.5 9Z"
              fill="#00684A"
            />
            <path
              d="M16.5 24V32C16.5 32 15 30 15 28C15 26 16.5 24 16.5 24Z"
              fill="#00ED64"
            />
          </svg>
        </div>

        {/* Title */}
        <H1 style={{ marginBottom: '12px', color: palette.gray.dark3 }}>
          ThreatSight 360
        </H1>
        
        <Description style={{ marginBottom: '32px', color: palette.gray.dark1 }}>
          Financial Intelligence & Compliance Platform
        </Description>

        {/* Error Banner */}
        {error && (
          <Banner
            variant="danger"
            style={{ marginBottom: '24px', textAlign: 'left' }}
          >
            {getErrorMessage(error)}
          </Banner>
        )}

        {/* Sign In Button */}
        <Button
          variant="primary"
          size="large"
          onClick={handleSignIn}
          disabled={isLoading}
          leftGlyph={<Icon glyph="Lock" />}
          style={{
            width: '100%',
            marginBottom: '24px',
            fontSize: '16px',
            padding: '16px',
            backgroundColor: palette.green.dark2,
            borderColor: palette.green.dark2,
          }}
        >
          {isLoading ? 'Signing in...' : 'Sign in with Cognito'}
        </Button>

        {/* Info Text */}
        <Body style={{ color: palette.gray.base, fontSize: '14px' }}>
          Secure authentication powered by AWS Cognito
        </Body>

        {/* Footer */}
        <div style={{
          marginTop: '32px',
          paddingTop: '24px',
          borderTop: `1px solid ${palette.gray.light2}`,
        }}>
          <Body style={{ color: palette.gray.base, fontSize: '12px' }}>
            Need help? Contact your system administrator
          </Body>
        </div>
      </Card>

      {/* Background decoration */}
      <div style={{
        position: 'fixed',
        bottom: 0,
        left: 0,
        right: 0,
        height: '200px',
        background: `linear-gradient(to top, rgba(0, 0, 0, 0.2), transparent)`,
        pointerEvents: 'none',
        zIndex: 0,
      }} />
    </div>
  );
}
