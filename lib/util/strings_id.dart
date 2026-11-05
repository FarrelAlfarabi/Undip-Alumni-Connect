import '../config/policy_config.dart';
import '../models/business.dart' show kMaxBusinesses;

/// Indonesian text for the English text used in the code (see [tr]). Add a
/// line here when an English text in the code needs an Indonesian version.
final Map<String, String> kIndonesian = {
  "This link isn't valid or can't be opened.":
      'Tautan ini tidak valid atau tidak bisa dibuka.',
  'Announcement': 'Pengumuman',
  // Notification times
  'Just now': 'Baru saja',
  'm ago': ' menit lalu',
  'h ago': ' jam lalu',
  'd ago': ' hari lalu',
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
  // Screens (batch 1)
  'Who runs this app': 'Siapa yang menjalankan aplikasi ini',
  'Announcements': 'Pengumuman',
  'New announcement': 'Pengumuman baru',
  'Search title, message or poster...': 'Cari judul, isi atau pemasang...',
  'Post announcement': 'Posting pengumuman',
  'Feedback': 'Masukan',
  'No feedback yet.': 'Belum ada masukan.',
  'Search message, name or screen...': 'Cari isi, nama atau layar...',
  'Nothing matches.': 'Tidak ada yang cocok.',
  'Mark as seen': 'Tandai sudah dilihat',
  'Mark as done': 'Tandai selesai',
  'Home order': 'Urutan Home',
  'Products': 'Produk',
  'Hide this content?': 'Sembunyikan konten ini?',
  'Reason (shown to the owner)': 'Alasan (ditampilkan ke pemilik)',
  'Cancel': 'Batal',
  'Hide': 'Sembunyikan',
  'Reason (kept for admins)': 'Alasan (hanya untuk admin)',
  'Suspend': 'Tangguhkan',
  'Hidden items': 'Item tersembunyi',
  'Search title, owner, note or reason...':
      'Cari judul, pemilik, catatan atau alasan...',
  'Clear search': 'Hapus pencarian',
  'Reports': 'Laporan',
  'Reported content: dismiss, hide, restore':
      'Konten yang dilaporkan: abaikan, sembunyikan, tampilkan lagi',
  'What testers sent from the Send feedback button':
      'Masukan dari penguji lewat tombol Kirim masukan',
  'Post news for all members, search past posts':
      'Posting kabar untuk semua anggota, cari posting lama',
  'Edit the contacts and socials members see':
      'Ubah kontak dan media sosial yang dilihat anggota',
  'Businesses': 'Bisnis',
  'Marketplace review': 'Tinjauan Marketplace',
  'Old listings waiting for review, report counts':
      'Produk lama yang menunggu tinjauan, jumlah laporan',
  'Admin': 'Admin',
  'Reject business': 'Tolak bisnis',
  'Suspend business': 'Tangguhkan bisnis',
  'Reason (shown to the owner, optional)':
      'Alasan (ditampilkan ke pemilik, opsional)',
  'Search name, owner or link...': 'Cari nama, pemilik atau link...',
  'Nothing here.': 'Belum ada apa-apa.',
  'Reject': 'Tolak',
  'Approve': 'Setujui',
  'Restore': 'Pulihkan',
  'No announcements yet.': 'Belum ada pengumuman.',
  'Full Name': 'Nama lengkap',
  'Phone (optional)': 'Telepon (opsional)',
  'Review Application': 'Periksa lamaran',
  'Not provided': 'Tidak diisi',
  'LinkedIn URL': 'Link LinkedIn',
  'Portfolio / other link': 'Portofolio / link lain',
  'Cover note': 'Surat pengantar',
  'Not attached': 'Tidak dilampirkan',
  'Confirm & Submit': 'Konfirmasi dan kirim',
  'Back to Edit': 'Kembali mengubah',
  'Back to Job': 'Kembali ke lowongan',
  'My businesses': 'Bisnis saya',
  'Search by name or category...': 'Cari nama atau kategori...',
  'No businesses match this search.': 'Tidak ada bisnis yang cocok.',
  'Register a business': 'Daftarkan bisnis',
  'Instagram / social': 'Instagram / media sosial',
  'Photo (optional)': 'Foto (opsional)',
  'Business name *': 'Nama bisnis *',
  'Short description *': 'Deskripsi singkat *',
  'Category *': 'Kategori *',
  'Personal business': 'Usaha perorangan',
  'Instagram *': 'Instagram *',
  'Website link (optional)': 'Link website (opsional)',
  'Yearly sales *': 'Penjualan per tahun *',
  'Type a message...': 'Tulis pesan...',
  'Delete your account for good?': 'Hapus akunmu selamanya?',
  'This cannot be undone.': 'Ini tidak bisa dibatalkan.',
  'What is removed': 'Yang dihapus',
  'What is kept': 'Yang disimpan',
  'Contact admin': 'Hubungi admin',
  'Email the admin team': 'Kirim email ke tim admin',
  'Send feedback': 'Kirim masukan',
  'Something broken or confusing?': 'Ada yang rusak atau membingungkan?',
  'Exit the app?': 'Keluar dari aplikasi?',
  'No applications yet.': 'Belum ada lamaran.',
  'Job Board': 'Daftar lowongan',
  'My job postings': 'Lowongan saya',
  'Post a Job': 'Pasang lowongan',
  'Search by title, company, or description...':
      'Cari judul, perusahaan atau deskripsi...',
  'No jobs match these filters.':
      'Tidak ada lowongan yang cocok dengan filter ini.',
  'Job Details': 'Detail lowongan',
  'View Applicants': 'Lihat pelamar',
  'Apply to this Job': 'Lamar lowongan ini',
  'Reject listing': 'Tolak produk',
  'Reason (shown to the seller)': 'Alasan (ditampilkan ke penjual)',
  'Nothing waiting for review.': 'Tidak ada yang menunggu tinjauan.',
  'This shop link is not valid.': 'Link toko ini tidak valid.',
  'Could not open the shop link.': 'Link toko tidak bisa dibuka.',
  'Seller profile not found.': 'Profil penjual tidak ditemukan.',
  'Could not open the seller profile.': 'Profil penjual tidak bisa dibuka.',
  'Visit shop': 'Kunjungi toko',
  'Contact seller': 'Hubungi penjual',
  'Report listing': 'Laporkan produk',
  'Price (whole rupiah)': 'Harga (rupiah utuh)',
  'Online shop link (optional)': 'Link toko online (opsional)',
  'Contact info (optional)': 'Info kontak (opsional)',
  'WhatsApp, phone, email, social media...':
      'WhatsApp, telepon, email, media sosial...',
  'Note (optional)': 'Catatan (opsional)',
  'Send report': 'Kirim laporan',
  'Search by title...': 'Cari judul...',
  'No listings match these filters.':
      'Tidak ada produk yang cocok dengan filter ini.',
  'Search by name...': 'Cari nama...',
  'No conversations match these filters.': 'Tidak ada percakapan yang cocok.',
  'Mark as sold?': 'Tandai terjual?',
  'Delete this listing?': 'Hapus produk ini?',
  'Could not load your listings. Try again.':
      'Produkmu gagal dimuat. Coba lagi.',
  'Edit': 'Ubah',
  'Mark as sold': 'Tandai terjual',
  'Delete': 'Hapus',
  'Notifications': 'Notifikasi',
  'Job Title': 'Judul lowongan',
  'Contact Info (email, phone, etc.)': 'Info kontak (email, telepon, dll.)',
  'Notify me when someone applies': 'Beri tahu saya saat ada yang melamar',
  'Post Job': 'Pasang lowongan',
  'My business': 'Bisnis saya',
  'Sign out': 'Keluar',
  'Edit Employment Info': 'Ubah info pekerjaan',
  'Current Role': 'Jabatan sekarang',
  'Sign Out & Verify Again': 'Keluar dan verifikasi ulang',
  'Save': 'Simpan',
  'Details copied.': 'Detail disalin.',
  'What were you doing? (optional)': 'Sedang apa kamu tadi? (opsional)',
  'Copy details': 'Salin detail',
  'Close': 'Tutup',
};
