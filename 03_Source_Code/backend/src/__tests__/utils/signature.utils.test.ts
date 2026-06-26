import { describe, test, expect, beforeAll } from "vitest";
import crypto from "crypto";

/**
 * Test untuk signature.utils.ts — RSA-2048 Digital Signature.
 *
 * Test ini men-generate pasangan kunci RSA secara in-memory untuk isolasi
 * (tidak bergantung pada .env). Kunci di-inject ke process.env sebelum
 * import modul.
 */

// Generate test RSA key pair sekali sebelum semua test
const { privateKey, publicKey } = crypto.generateKeyPairSync("rsa", {
  modulusLength: 2048,
  publicKeyEncoding: { type: "spki", format: "pem" },
  privateKeyEncoding: { type: "pkcs8", format: "pem" },
});

// Konversi ke format .env (newline → \n literal)
const toEnvFormat = (pem: string) => pem.replace(/\n/g, "\\n");

// Set env sebelum import modul
process.env.RSA_PRIVATE_KEY = toEnvFormat(privateKey);
process.env.RSA_PUBLIC_KEY = toEnvFormat(publicKey);

import { signContent, verifySignature } from "../../utils/signature.utils.js";

const SAMPLE_PAYLOAD = "sha256hash|report-uuid-123|user-uuid-456|2026-06-26T04:00:00.000Z";

describe("signContent", () => {
  test("menghasilkan string non-empty", () => {
    const signature = signContent(SAMPLE_PAYLOAD);
    expect(signature).toBeTruthy();
    expect(typeof signature).toBe("string");
  });

  test("output berformat Base64 (bukan hex)", () => {
    const signature = signContent(SAMPLE_PAYLOAD);
    // Base64 valid hanya mengandung A-Z, a-z, 0-9, +, /, =
    expect(/^[A-Za-z0-9+/]+=*$/.test(signature)).toBe(true);
  });

  test("panjang signature RSA-2048 sekitar 344 chars (base64 dari 256 bytes)", () => {
    const signature = signContent(SAMPLE_PAYLOAD);
    // RSA-2048 menghasilkan 256 bytes → base64 = ~344 chars
    expect(signature.length).toBeGreaterThan(300);
    expect(signature.length).toBeLessThan(400);
  });

  test("signature berbeda untuk payload berbeda", () => {
    const sig1 = signContent(SAMPLE_PAYLOAD);
    const sig2 = signContent("different|payload|here");
    expect(sig1).not.toBe(sig2);
  });
});

describe("verifySignature", () => {
  test("verifikasi berhasil untuk signature yang valid", () => {
    const signature = signContent(SAMPLE_PAYLOAD);
    expect(verifySignature(SAMPLE_PAYLOAD, signature)).toBe(true);
  });

  test("verifikasi gagal jika data dimanipulasi (tampered)", () => {
    const signature = signContent(SAMPLE_PAYLOAD);
    const tamperedData = SAMPLE_PAYLOAD.replace("report-uuid-123", "report-uuid-HACKED");
    expect(verifySignature(tamperedData, signature)).toBe(false);
  });

  test("verifikasi gagal jika signature dimanipulasi", () => {
    const signature = signContent(SAMPLE_PAYLOAD);
    const tamperedSignature = signature.slice(0, -4) + "XXXX";
    expect(verifySignature(SAMPLE_PAYLOAD, tamperedSignature)).toBe(false);
  });

  test("verifikasi gagal untuk signature kosong", () => {
    expect(verifySignature(SAMPLE_PAYLOAD, "")).toBe(false);
  });

  test("verifikasi gagal untuk signature yang sama sekali berbeda", () => {
    expect(verifySignature(SAMPLE_PAYLOAD, "aGVsbG8gd29ybGQ=")).toBe(false);
  });

  test("round-trip: sign lalu verify dengan payload multiline", () => {
    const complexPayload = JSON.stringify({
      content_hash: "abc123def456",
      report_id: "rpt-001",
      signer: "dok-patologi-001",
      timestamp: new Date().toISOString(),
    });
    const sig = signContent(complexPayload);
    expect(verifySignature(complexPayload, sig)).toBe(true);
  });
});

describe("Integritas RSA Key", () => {
  test("melempar error jika RSA_PRIVATE_KEY tidak di-set", () => {
    const original = process.env.RSA_PRIVATE_KEY;
    delete process.env.RSA_PRIVATE_KEY;

    expect(() => signContent("test")).toThrow("RSA_PRIVATE_KEY");

    process.env.RSA_PRIVATE_KEY = original;
  });

  test("verifySignature mengembalikan false (bukan throw) jika RSA_PUBLIC_KEY tidak di-set", () => {
    const original = process.env.RSA_PUBLIC_KEY;
    delete process.env.RSA_PUBLIC_KEY;

    // verifySignature harus graceful — return false, tidak crash
    expect(verifySignature("test", "invalidsig")).toBe(false);

    process.env.RSA_PUBLIC_KEY = original;
  });
});
