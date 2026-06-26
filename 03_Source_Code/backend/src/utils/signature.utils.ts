import crypto from "crypto";

/**
 * Digital Signature menggunakan RSA-2048 dengan SHA-256 (RSA-SHA256).
 *
 * Perbedaan dengan SHA-256 hash biasa:
 * - Hash (SHA-256): siapapun bisa menghitung hash yang sama → tidak bisa
 *   membuktikan SIAPA yang menandatangani.
 * - Digital Signature (RSA-SHA256): hanya pemilik PRIVATE KEY yang bisa
 *   membuat signature yang valid → bisa diverifikasi oleh siapapun
 *   menggunakan PUBLIC KEY, membuktikan identitas dan integritas (non-repudiation).
 *
 * Format output signature: Base64 string (lebih panjang dari SHA-256 hex)
 *   Contoh panjang: SHA-256 hex = 64 chars, RSA-2048 signature = ~344 chars base64
 *
 * Environment variables:
 *   RSA_PRIVATE_KEY — PEM format, newlines sebagai \n literal
 *   RSA_PUBLIC_KEY  — PEM format, newlines sebagai \n literal
 *
 * Generate kunci:
 *   npx tsx scripts/generate-rsa-keys.ts
 */

const normalizePem = (raw: string): string =>
  // Ganti literal \n (dari .env) menjadi newline nyata
  raw.replace(/\\n/g, "\n");

const getPrivateKey = (): string => {
  const raw = process.env.RSA_PRIVATE_KEY;
  if (!raw) {
    throw new Error(
      "RSA_PRIVATE_KEY belum diset di environment variable. " +
      "Jalankan: npx tsx scripts/generate-rsa-keys.ts"
    );
  }
  return normalizePem(raw);
};

const getPublicKey = (): string => {
  const raw = process.env.RSA_PUBLIC_KEY;
  if (!raw) {
    throw new Error(
      "RSA_PUBLIC_KEY belum diset di environment variable. " +
      "Jalankan: npx tsx scripts/generate-rsa-keys.ts"
    );
  }
  return normalizePem(raw);
};

/**
 * Tanda tangani data dengan RSA-2048 private key.
 * @param data - String apapun (misal: JSON.stringify(snapshot) atau composite string)
 * @returns Base64-encoded RSA signature
 */
export const signContent = (data: string): string => {
  const privateKey = getPrivateKey();
  const sign = crypto.createSign("RSA-SHA256");
  sign.update(data, "utf-8");
  sign.end();
  return sign.sign(privateKey, "base64");
};

/**
 * Verifikasi signature dengan RSA-2048 public key.
 * @param data      - Data asli yang ditandatangani
 * @param signature - Base64 signature hasil signContent()
 * @returns true jika signature valid dan data tidak dimanipulasi
 */
export const verifySignature = (data: string, signature: string): boolean => {
  try {
    const publicKey = getPublicKey();
    const verify = crypto.createVerify("RSA-SHA256");
    verify.update(data, "utf-8");
    verify.end();
    return verify.verify(publicKey, signature, "base64");
  } catch {
    return false;
  }
};
