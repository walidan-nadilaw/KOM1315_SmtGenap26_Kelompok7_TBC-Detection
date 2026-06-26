import { describe, test, expect, beforeAll } from "vitest";

/**
 * Test untuk crypto.utils.ts — AES-256-ECB field-level encryption.
 *
 * Catatan: AES_SECRET_KEY di-set via vitest.config.ts (env block).
 * Key harus 64 hex chars (= 32 bytes untuk AES-256).
 */

// Set env sebelum import modul yang membutuhkannya
process.env.AES_SECRET_KEY = "a".repeat(64); // 64 hex chars = key valid untuk test

import { encryptField, decryptField } from "../../utils/crypto.utils.js";

const SAMPLE_NIK = "3201010101010001";
const SAMPLE_BPJS = "0001112223334";

describe("encryptField", () => {
  test("menghasilkan output berbeda dari input plaintext", () => {
    const result = encryptField(SAMPLE_NIK);
    expect(result).not.toBe(SAMPLE_NIK);
  });

  test("output dimulai dengan prefix 'aes256ecb:'", () => {
    const result = encryptField(SAMPLE_NIK);
    expect(result.startsWith("aes256ecb:")).toBe(true);
  });

  test("enkripsi bersifat deterministik — input sama menghasilkan output sama", () => {
    const result1 = encryptField(SAMPLE_NIK);
    const result2 = encryptField(SAMPLE_NIK);
    expect(result1).toBe(result2);
  });

  test("input berbeda menghasilkan ciphertext berbeda", () => {
    const result1 = encryptField(SAMPLE_NIK);
    const result2 = encryptField(SAMPLE_BPJS);
    expect(result1).not.toBe(result2);
  });

  test("idempoten — enkripsi ulang pada ciphertext tidak double-encrypt", () => {
    const first = encryptField(SAMPLE_NIK);
    const second = encryptField(first); // input sudah ciphertext
    expect(second).toBe(first);        // harus sama, tidak di-wrap lagi
  });

  test("mengenkripsi BPJS number dengan benar", () => {
    const result = encryptField(SAMPLE_BPJS);
    expect(result.startsWith("aes256ecb:")).toBe(true);
    expect(result).not.toBe(SAMPLE_BPJS);
  });
});

describe("decryptField", () => {
  test("mendekripsi ke plaintext asli (round-trip)", () => {
    const ciphertext = encryptField(SAMPLE_NIK);
    const decrypted = decryptField(ciphertext);
    expect(decrypted).toBe(SAMPLE_NIK);
  });

  test("round-trip untuk BPJS number", () => {
    const ciphertext = encryptField(SAMPLE_BPJS);
    const decrypted = decryptField(ciphertext);
    expect(decrypted).toBe(SAMPLE_BPJS);
  });

  test("backward-compatible — data plaintext lama dikembalikan apa adanya", () => {
    // Data yang belum dimigrasi (tidak punya prefix) harus dikembalikan langsung
    const plaintext = "3201010101010001";
    expect(decryptField(plaintext)).toBe(plaintext);
  });

  test("round-trip untuk string dengan karakter spesial", () => {
    const sample = "test-data-123";
    expect(decryptField(encryptField(sample))).toBe(sample);
  });
});

describe("Integritas AES Key", () => {
  test("melempar error jika AES_SECRET_KEY tidak di-set", () => {
    const originalKey = process.env.AES_SECRET_KEY;
    delete process.env.AES_SECRET_KEY;

    expect(() => encryptField("test")).toThrow("AES_SECRET_KEY");

    // Restore
    process.env.AES_SECRET_KEY = originalKey;
  });

  test("melempar error jika AES_SECRET_KEY panjangnya tidak tepat", () => {
    const originalKey = process.env.AES_SECRET_KEY;
    process.env.AES_SECRET_KEY = "tooshort";

    expect(() => encryptField("test")).toThrow("AES_SECRET_KEY");

    // Restore
    process.env.AES_SECRET_KEY = originalKey;
  });
});
