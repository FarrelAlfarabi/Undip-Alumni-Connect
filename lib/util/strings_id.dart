import '../config/policy_config.dart';
import '../models/business.dart' show kMaxBusinesses;

/// Indonesian text for the English text used in the code (see [tr]). Add a
/// line here when an English text in the code needs an Indonesian version.
final Map<String, String> kIndonesian = {
  // Generic errors
  'Something went wrong. Please try again.': 'Terjadi kesalahan. Coba lagi.',
  "Couldn't reach the server. Check your connection and try again.":
      'Tidak bisa terhubung ke server. Periksa koneksimu lalu coba lagi.',
  // Reports
  'Only verified alumni can send reports.':
      'Hanya alumni terverifikasi yang bisa mengirim laporan.',
  'You cannot report your own content.':
      'Kamu tidak bisa melaporkan kontenmu sendiri.',
  'You already reported this. An admin will take a look.':
      'Kamu sudah melaporkan ini. Admin akan memeriksanya.',
  'This content no longer exists.': 'Konten ini sudah tidak ada.',
  'The note is too long (300 characters at most).':
      'Catatannya terlalu panjang (maksimal 300 karakter).',
  // Marketplace
  'You can only change your own listings.':
      'Kamu hanya bisa mengubah produkmu sendiri.',
  'This listing no longer exists.': 'Produk ini sudah tidak ada.',
  'You are not an admin.': 'Kamu bukan admin.',
  'Give a reason for rejecting.': 'Tulis alasan penolakan.',
  'You already reported this listing.': 'Kamu sudah melaporkan produk ini.',
  'This listing cannot be changed in its current state.':
      'Produk ini tidak bisa diubah dalam status sekarang.',
  'Adding products is for owners of approved businesses. Register your '
          'business first and wait for approval.':
      'Menambah produk hanya untuk pemilik bisnis yang sudah disetujui. '
      'Daftarkan bisnismu dulu dan tunggu persetujuan.',
  'You have reached the free product limit for this business. Your '
          'products stay visible and you can still edit or delete them. To add '
          'more, please contact an admin about unlimited posting.':
      'Batas produk gratis untuk bisnis ini sudah tercapai. Produkmu tetap '
      'tampil dan masih bisa diubah atau dihapus. Untuk menambah lagi, '
      'hubungi admin soal posting tanpa batas.',
  // Business
  'Only verified alumni can use the business directory.':
      'Hanya alumni terverifikasi yang bisa memakai direktori bisnis.',
  'Add the business Instagram (@username or a link). The website is optional.':
      'Isi Instagram bisnis (@username atau link). Website boleh dikosongkan.',
  'One of the links is not valid. Use a full link that starts '
          'with http:// or https://.':
      'Salah satu link tidak valid. Pakai link lengkap yang diawali '
      'http:// atau https://.',
  'Another business already uses one of these links.':
      'Bisnis lain sudah memakai salah satu link ini.',
  'Check the name (2 to 100 characters) and the description '
          '(up to 500 characters).':
      'Periksa nama (2 sampai 100 karakter) dan deskripsi '
      '(maksimal 500 karakter).',
  'Choose a category.': 'Pilih kategori.',
  'Choose the yearly sales band.': 'Pilih skala penjualan per tahun.',
  'You already have $kMaxBusinesses businesses. To add more, '
          'email $kContactEmail.':
      'Kamu sudah punya $kMaxBusinesses bisnis. Untuk menambah, kirim email '
      'ke $kContactEmail.',
  'This business no longer exists.': 'Bisnis ini sudah tidak ada.',
  'You can only change your own business.':
      'Kamu hanya bisa mengubah bisnismu sendiri.',
  'This business can no longer be edited here. Please contact '
          'an admin.':
      'Bisnis ini tidak bisa diubah lagi di sini. Hubungi admin.',
  // Admin
  'Choose one of the four bands.': 'Pilih salah satu dari empat skala.',
  'A reason is required.': 'Alasan wajib diisi.',
  'That is not possible right now. You cannot suspend an admin or '
          'yourself. Otherwise reload the list.':
      'Itu belum bisa dilakukan sekarang. Kamu tidak bisa menangguhkan admin '
      'atau dirimu sendiri. Kalau bukan itu, muat ulang daftarnya.',
  'This item no longer exists.': 'Item ini sudah tidak ada.',
  'Title and message are required, and must not be too long.':
      'Judul dan isi wajib diisi, dan tidak boleh terlalu panjang.',
};
