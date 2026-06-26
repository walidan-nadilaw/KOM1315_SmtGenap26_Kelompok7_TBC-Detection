import { describe, test, expect, vi, beforeEach } from 'vitest';
import { AppError } from '../../errors/app.error.js';

vi.mock('../../config/prisma.js', () => ({
  prisma: {
    patient: {
      findUnique: vi.fn(),
      create: vi.fn(),
      count: vi.fn(),
      findMany: vi.fn(),
      update: vi.fn(),
    },
    $transaction: vi.fn(),
  },
}));

// Mock crypto.utils agar unit test terisolasi dari implementasi AES
// — mengembalikan nilai deterministik yang mudah diverifikasi
vi.mock('../../utils/crypto.utils.js', () => ({
  encryptField: vi.fn((val: string) => `encrypted:${val}`),
  decryptField: vi.fn((val: string) =>
    val.startsWith('encrypted:') ? val.slice('encrypted:'.length) : val
  ),
}));

// Mock audit utils agar tidak ada side-effect DB pada unit test
vi.mock('../../utils/audit.utils.js', () => ({
  writeAuditLog: vi.fn().mockResolvedValue(undefined),
}));

import { createPatient, listPatients, getPatientById, updatePatient } from '../../services/patient.service.js';
import { prisma } from '../../config/prisma.js';

// Mock patient as stored in DB: NIK dan BPJS sudah dalam bentuk ciphertext
const mockPatientInDb = {
  id: 'patient-123',
  name: 'Ahmad',
  no_induk: 'encrypted:3201010000000001',   // ciphertext di DB
  bpjs_number: null,
  sex: 'LAKI_LAKI',
  age: 45,
  created_by: 'operator-123',
  created_at: new Date(),
  updated_at: new Date(),
};

// Patient seperti yang seharusnya dikembalikan ke caller (sudah terdekripsi)
const mockPatientDecrypted = {
  ...mockPatientInDb,
  no_induk: '3201010000000001',   // plaintext setelah dekripsi
};

describe('createPatient', () => {
  beforeEach(() => vi.clearAllMocks());

  test('throws 409 jika NIK sudah terdaftar', async () => {
    vi.mocked(prisma.patient.findUnique).mockResolvedValue(mockPatientInDb as any);
    await expect(
      createPatient({ name: 'Budi', no_induk: '3201010000000001', sex: 'LAKI_LAKI' as any, age: 30 }, 'op-1')
    ).rejects.toThrow('NIK sudah terdaftar');
  });

  test('throws 409 jika BPJS sudah terdaftar', async () => {
    vi.mocked(prisma.patient.findUnique)
      .mockResolvedValueOnce(null)  // NIK tidak konflik
      .mockResolvedValueOnce(mockPatientInDb as any);  // BPJS konflik
    await expect(
      createPatient({ name: 'Budi', no_induk: '9999999999999999', sex: 'LAKI_LAKI' as any, age: 30, bpjs_number: '0000111122221' }, 'op-1')
    ).rejects.toThrow('BPJS sudah terdaftar');
  });

  test('creates patient dan mengembalikan data terdekripsi', async () => {
    vi.mocked(prisma.patient.findUnique).mockResolvedValue(null);
    vi.mocked(prisma.patient.create).mockResolvedValue(mockPatientInDb as any);

    const result = await createPatient(
      { name: 'Ahmad', no_induk: '3201010000000001', sex: 'LAKI_LAKI' as any, age: 45 },
      'op-1'
    );

    // Caller harus menerima NIK plaintext, bukan ciphertext
    expect(result.no_induk).toBe('3201010000000001');
  });

  test('prisma.patient.create dipanggil dengan NIK terenkripsi', async () => {
    vi.mocked(prisma.patient.findUnique).mockResolvedValue(null);
    vi.mocked(prisma.patient.create).mockResolvedValue(mockPatientInDb as any);

    await createPatient(
      { name: 'Ahmad', no_induk: '3201010000000001', sex: 'LAKI_LAKI' as any, age: 45 },
      'op-1'
    );

    const callArgs = vi.mocked(prisma.patient.create).mock.calls[0]?.[0]?.data as any;
    // Data yang masuk ke DB harus ciphertext, bukan plaintext
    expect(callArgs.no_induk).toBe('encrypted:3201010000000001');
  });
});

describe('getPatientById', () => {
  beforeEach(() => vi.clearAllMocks());

  test('throws 404 jika patient tidak ditemukan', async () => {
    vi.mocked(prisma.patient.findUnique).mockResolvedValue(null);
    await expect(getPatientById('nonexistent-id')).rejects.toThrow('Pasien tidak ditemukan');
  });

  test('mengembalikan patient dengan NIK terdekripsi', async () => {
    const patientWithCases = { ...mockPatientInDb, cases: [] };
    vi.mocked(prisma.patient.findUnique).mockResolvedValue(patientWithCases as any);

    const result = await getPatientById('patient-123');
    expect(result.id).toBe('patient-123');
    // NIK harus sudah terdekripsi
    expect(result.no_induk).toBe('3201010000000001');
  });
});

describe('listPatients', () => {
  beforeEach(() => vi.clearAllMocks());

  test('mengembalikan data terdekripsi dan meta pagination', async () => {
    vi.mocked(prisma.$transaction).mockResolvedValue([2, [mockPatientInDb, mockPatientInDb]] as any);

    const result = await listPatients({ page: '1', limit: '10' });

    expect(result.data).toHaveLength(2);
    expect(result.meta.total).toBe(2);
    expect(result.meta.page).toBe(1);
    // Semua data harus terdekripsi
    expect(result.data[0]!.no_induk).toBe('3201010000000001');
  });

  test('meta limit sesuai query', async () => {
    vi.mocked(prisma.$transaction).mockResolvedValue([0, []] as any);
    const result = await listPatients({ page: '2', limit: '5' });
    expect(result.meta.page).toBe(2);
    expect(result.meta.limit).toBe(5);
  });
});

describe('updatePatient', () => {
  beforeEach(() => vi.clearAllMocks());

  test('throws 404 jika patient tidak ditemukan', async () => {
    vi.mocked(prisma.patient.findUnique).mockResolvedValue(null);
    await expect(updatePatient('nonexistent-id', { name: 'Budi' }, 'operator-1')).rejects.toThrow('Pasien tidak ditemukan');
  });

  test('throws 409 jika NIK sudah terdaftar pada pasien lain', async () => {
    vi.mocked(prisma.patient.findUnique)
      .mockResolvedValueOnce(mockPatientInDb as any)   // pasien yang diupdate
      .mockResolvedValueOnce({ id: 'other-id' } as any); // NIK konflik

    await expect(
      updatePatient('patient-123', { no_induk: '1111222233334444' }, 'operator-1')
    ).rejects.toThrow('NIK sudah terdaftar pada pasien lain');
  });

  test('throws 409 jika BPJS sudah terdaftar pada pasien lain', async () => {
    vi.mocked(prisma.patient.findUnique)
      .mockResolvedValueOnce(mockPatientInDb as any)   // pasien yang diupdate
      .mockResolvedValueOnce({ id: 'other-id' } as any); // BPJS konflik

    await expect(
      updatePatient('patient-123', { bpjs_number: '1111222233334' }, 'operator-1')
    ).rejects.toThrow('Nomor BPJS sudah terdaftar pada pasien lain');
  });

  test('updates patient dan mengembalikan data terdekripsi', async () => {
    vi.mocked(prisma.patient.findUnique).mockResolvedValueOnce(mockPatientInDb as any);
    vi.mocked(prisma.patient.update).mockResolvedValue({
      ...mockPatientInDb,
      name: 'Budi',
    } as any);

    const result = await updatePatient('patient-123', { name: 'Budi' }, 'operator-1');
    expect(result.name).toBe('Budi');
    expect(result.no_induk).toBe('3201010000000001');  // terdekripsi
  });
});
