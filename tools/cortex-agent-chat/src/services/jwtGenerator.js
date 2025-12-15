/**
 * JWT Generator for Snowflake Key-Pair Authentication
 * 
 * Generates JWT tokens client-side using RSA private key for authenticating
 * with Snowflake REST APIs. Tokens are signed with RS256 (RSA-SHA256).
 */

import KJUR from 'jsrsasign';

/**
 * Generate a JWT token for Snowflake REST API authentication
 * 
 * @param {string} account - Snowflake account identifier (e.g., "xy12345.us-east-1")
 * @param {string} user - Snowflake username
 * @param {string} privateKey - RSA private key in PEM format
 * @param {number} expiresInSeconds - Token expiration time (default: 3600 = 1 hour)
 * @returns {string} Signed JWT token
 * @throws {Error} If key format is invalid or signing fails
 */
export const generateJWT = (account, user, privateKey, expiresInSeconds = 3600) => {
  try {
    // Validate inputs
    if (!account || !account.trim()) {
      throw new Error('Snowflake account is required');
    }
    if (!user || !user.trim()) {
      throw new Error('Snowflake user is required');
    }
    if (!privateKey || !privateKey.trim()) {
      throw new Error('Private key is required');
    }

    // Normalize account identifier (remove .snowflakecomputing.com if present)
    const accountIdentifier = account.trim().replace('.snowflakecomputing.com', '');
    const username = user.trim().toUpperCase();

    // Construct qualified username (account.user format)
    const qualifiedUsername = `${accountIdentifier}.${username}`;

    // Current time and expiration
    const now = Math.floor(Date.now() / 1000);
    const exp = now + expiresInSeconds;

    // JWT Header
    const header = {
      alg: 'RS256',
      typ: 'JWT'
    };

    // JWT Payload
    const payload = {
      iss: qualifiedUsername,  // Issuer (qualified username)
      sub: qualifiedUsername,  // Subject (qualified username)
      iat: now,                // Issued at
      exp: exp                 // Expiration time
    };

    // Sign the JWT with the private key
    const sHeader = JSON.stringify(header);
    const sPayload = JSON.stringify(payload);

    // Parse private key (supports PKCS#8 and PKCS#1 formats)
    let privateKeyObj;
    try {
      privateKeyObj = KJUR.KEYUTIL.getKey(privateKey.trim());
    } catch (keyError) {
      throw new Error(`Invalid private key format: ${keyError.message}. Ensure the key is in PEM format (PKCS#8 or PKCS#1).`);
    }

    // Generate JWT token
    const token = KJUR.jws.JWS.sign('RS256', sHeader, sPayload, privateKeyObj);

    return token;
  } catch (error) {
    throw new Error(`JWT generation failed: ${error.message}`);
  }
};

/**
 * Validate if a JWT token is expired or about to expire
 * 
 * @param {string} token - JWT token to validate
 * @param {number} bufferSeconds - Consider expired if expiring within this buffer (default: 300 = 5 minutes)
 * @returns {boolean} True if token is expired or about to expire
 */
export const isTokenExpired = (token, bufferSeconds = 300) => {
  try {
    if (!token || !token.trim()) {
      return true;
    }

    // Decode the JWT payload
    const parts = token.split('.');
    if (parts.length !== 3) {
      return true;
    }

    const payload = JSON.parse(atob(parts[1]));
    const exp = payload.exp;

    if (!exp) {
      return true;
    }

    const now = Math.floor(Date.now() / 1000);
    return exp <= (now + bufferSeconds);
  } catch (error) {
    return true;
  }
};

/**
 * JWT Token Manager - Handles token generation and caching
 */
export class JWTTokenManager {
  constructor(account, user, privateKey) {
    this.account = account;
    this.user = user;
    this.privateKey = privateKey;
    this.cachedToken = null;
  }

  /**
   * Get a valid JWT token (generates new if expired or missing)
   * 
   * @returns {string} Valid JWT token
   */
  getToken() {
    if (!this.cachedToken || isTokenExpired(this.cachedToken)) {
      this.cachedToken = generateJWT(this.account, this.user, this.privateKey);
    }
    return this.cachedToken;
  }

  /**
   * Force refresh the token
   * 
   * @returns {string} New JWT token
   */
  refreshToken() {
    this.cachedToken = generateJWT(this.account, this.user, this.privateKey);
    return this.cachedToken;
  }

  /**
   * Clear cached token
   */
  clearToken() {
    this.cachedToken = null;
  }
}

