import '../config/policy_config.dart';
import '../models/business.dart' show kMaxBusinesses;

/// Indonesian text for the English text used in the code (see [tr]). Add a
/// line here when an English text in the code needs an Indonesian version.
final Map<String, String> kIndonesian = {
  'All time': 'Semua waktu',
  'Micro': 'Mikro',
  'Small': 'Kecil',
  'Medium': 'Menengah',
  'Large (not UMKM)': 'Besar (bukan UMKM)',
  'Up to Rp 2 miliar a year': 'Sampai Rp 2 miliar per tahun',
  'Over Rp 2 miliar, up to Rp 15 miliar a year':
      'Di atas Rp 2 miliar, sampai Rp 15 miliar per tahun',
  'Over Rp 15 miliar, up to Rp 50 miliar a year':
      'Di atas Rp 15 miliar, sampai Rp 50 miliar per tahun',
  'Over Rp 50 miliar a year': 'Di atas Rp 50 miliar per tahun',
  'Approved': 'Disetujui',
  'Not approved': 'Belum disetujui',
  'Prohibited item': 'Barang terlarang',
  'Misleading': 'Menyesatkan',
  'Other': 'Lainnya',
  'Spam or scam': 'Spam atau penipuan',
  'Inappropriate': 'Tidak pantas',
  'Fake or pretending to be someone': 'Berpura-pura jadi orang lain',
  'Wrong information': 'Informasi salah',
  'Today': 'Hari ini',
  'Last 7 days': '7 hari terakhir',
  'Last 30 days': '30 hari terakhir',
  'Last 90 days': '90 hari terakhir',
  'City': 'Kota',
  'Edit announcement': 'Ubah pengumuman',
  'Every member sees this in Announcements right away.':
      'Semua anggota langsung melihat ini di Announcements.',
  'Changes show to every member right away.':
      'Perubahan langsung terlihat oleh semua anggota.',
  'Save changes': 'Simpan perubahan',
  'Enter a title.': 'Isi judul.',
  'Enter the message.': 'Isi pesannya.',
  'by': 'oleh',
  'approved': 'disetujui',
  'By {0}': 'Oleh {0}',
  'report': 'laporan',
  'reports': 'laporan',
  'Suspended': 'Ditangguhkan',
  'Hidden': 'Disembunyikan',
  'Band chosen by owner: {0}{1}': 'Band pilihan pemilik: {0}{1}',
  'Hidden by an admin{0}. Other people cannot see this business or its products.': 'Disembunyikan oleh admin{0}. Orang lain tidak bisa melihat usaha ini atau produknya.',
  'Hidden by an admin{0}. Other people cannot see this product.':
      'Disembunyikan oleh admin{0}. Orang lain tidak bisa melihat produk ini.',
  'not given': 'tidak disebutkan',
  'No reason given': 'Tidak ada alasan',
  'no reason given': 'tidak ada alasan',
  'Rejected: {0}': 'Ditolak: {0}',
  'Not approved: {0}. Fix it and send it again.':
      'Belum disetujui: {0}. Perbaiki lalu kirim lagi.',
  'Apply — {0}': 'Lamar — {0}',
  'Review your application before submitting to {0}.':
      'Tinjau lamaranmu sebelum dikirim ke {0}.',
  'the poster': 'pemasang lowongan',
  'Applicants — {0}': 'Pelamar — {0}',
  // Texts with values (trf)
  'Error: {0}': 'Error: {0}',
  'Unlimited posting until {0} (set in the dashboard)':
      'Posting tanpa batas sampai {0} (diatur di dashboard)',
  'Reason: {0}': 'Alasan: {0}',
  'Website: {0}': 'Website: {0}',
  'Social: {0}': 'Sosial: {0}',
  'Posted {0}': 'Diposting {0}',
  'Step {0} of {1}': 'Langkah {0} dari {1}',
  'No messages yet. Say hello to {0}.': 'Belum ada pesan. Sapa {0}.',
  'Type {0} or your first name': 'Ketik {0} atau nama depanmu',
  'Posted by {0}': 'Diposting oleh {0}',
  'Contact: {0}': 'Kontak: {0}',
  'Shop: {0}': 'Toko: {0}',
  'Photo of {0}': 'Foto {0}',
  'Sort: {0}': 'Urut: {0}',
  'You have not registered a business yet. Register one so other alumni can find it.\n\n{0}': 'Kamu belum mendaftarkan usaha. Daftarkan satu agar alumni lain bisa menemukannya.\n\n{0}',
  '"{0}" will be removed for good.': '"{0}" akan dihapus selamanya.',
  'Post failed. {0}': 'Gagal memasang. {0}',
  'This sends a short error summary, the screen name ({0}), the app version and your device type. Emails, keys, links and long numbers are removed first.': 'Ini mengirim ringkasan galat singkat, nama layar ({0}), versi aplikasi dan jenis perangkatmu. Email, kunci, tautan dan angka panjang dihapus lebih dulu.',
  'Hide {0} options': 'Sembunyikan pilihan {0}',
  'Show {0} options': 'Tampilkan pilihan {0}',
  // Screen sweep (5 Nov)
  'This is a closed beta for a small group of FEB UNDIP alumni. Things can change or break. Use "Send feedback" when something looks wrong.': 'Ini beta tertutup untuk sekelompok kecil alumni FEB UNDIP. Hal-hal bisa berubah atau rusak. Pakai "Kirim masukan" kalau ada yang terlihat salah.',
  'About': 'Tentang',
  'Every member sees this in Announcements right away. It cannot be edited or removed from the app.': 'Semua anggota langsung melihat ini di Announcements. Tidak bisa diubah atau dihapus dari aplikasi.',
  'Message': 'Pesan',
  'Title': 'Judul',
  'Period': 'Periode',
  'Reason': 'Alasan',
  'Type': 'Jenis',
  'They cannot sign in and disappear from the Directory until you lift the suspension. Their posts and businesses stay as they are: hide those separately if needed.': 'Mereka tidak bisa masuk dan hilang dari Directory sampai kamu mencabut penangguhan. Postingan dan usaha mereka tetap ada: sembunyikan secara terpisah kalau perlu.',
  'Posted': 'Diposting',
  'Category': 'Kategori',
  'Application submitted': 'Lamaran terkirim',
  'Done': 'Selesai',
  'Phone': 'Telepon',
  'Review': 'Tinjau',
  'Details': 'Detail',
  'No businesses yet. Approved businesses run by alumni will show up here.':
      'Belum ada usaha. Usaha alumni yang disetujui akan muncul di sini.',
  'Instagram is required, the website is optional. Each link can be used by one business only.': 'Instagram wajib diisi, website opsional. Setiap tautan hanya bisa dipakai satu usaha.',
  'Where people can see it': 'Tempat orang bisa melihatnya',
  'Run only by you, the owner. It is still listed publicly like any other business.': 'Dijalankan hanya oleh kamu sebagai pemilik. Tetap ditampilkan secara publik seperti usaha lain.',
  'Remove': 'Hapus',
  'Refresh': 'Muat ulang',
  'After this you cannot verify again with the same email. If you change your mind, the Ikafe team can restore you from the alumni list.': 'Setelah ini kamu tidak bisa verifikasi lagi dengan email yang sama. Kalau berubah pikiran, tim Ikafe bisa memulihkanmu dari daftar alumni.',
  'This removes your account from Lingkaran.':
      'Ini menghapus akunmu dari Lingkaran.',
  'Industry': 'Industri',
  'Year': 'Angkatan',
  'Major': 'Jurusan',
  'Couldn\'t load this right now.': 'Tidak bisa memuat ini sekarang.',
  'Couldn\'t load announcements.': 'Tidak bisa memuat pengumuman.',
  'Exit': 'Keluar',
  'Stay': 'Tetap di sini',
  'Company': 'Perusahaan',
  'No jobs posted yet. Be the first alumnus to post one.':
      'Belum ada lowongan. Jadilah alumni pertama yang memasang lowongan.',
  'Applied': 'Sudah melamar',
  'Review queue': 'Antrean tinjauan',
  'Current photo of this listing': 'Foto produk saat ini',
  'Photo you picked': 'Foto yang kamu pilih',
  'Your contact info will be visible to other members.':
      'Info kontakmu akan terlihat oleh anggota lain.',
  'Add a shop link, contact info, or both. There is no checkout in the app.': 'Tambahkan tautan toko, info kontak, atau keduanya. Tidak ada pembayaran di dalam aplikasi.',
  'How buyers reach you': 'Cara pembeli menghubungimu',
  'Description': 'Deskripsi',
  'Saving changes sends this listing back to review. It stays hidden until an admin approves it again.': 'Menyimpan perubahan akan mengirim produk ini kembali ke tinjauan. Produk tetap tersembunyi sampai admin menyetujuinya lagi.',
  'Why are you reporting this listing?': 'Kenapa kamu melaporkan produk ini?',
  'No listings yet. Approved listings from other alumni will show up here.': 'Belum ada produk. Produk yang disetujui dari alumni lain akan muncul di sini.',
  'Could not load the marketplace. Check your connection and try again.':
      'Tidak bisa memuat marketplace. Periksa koneksimu lalu coba lagi.',
  'Faculty': 'Fakultas',
  'No conversations yet. Message an alumnus from the directory to get started.': 'Belum ada percakapan. Kirim pesan ke alumni dari direktori untuk memulai.',
  'This business is suspended. Please contact an admin.':
      'Usaha ini ditangguhkan. Hubungi admin.',
  'You have not posted a job yet. Jobs you post show up here with the people who applied.': 'Kamu belum memasang lowongan. Lowongan yang kamu pasang muncul di sini beserta orang yang melamar.',
  'Edit and save to send it for review again.':
      'Ubah dan simpan untuk mengirimnya ke tinjauan lagi.',
  'It will disappear from the marketplace. This cannot be undone.':
      'Produk akan hilang dari marketplace. Ini tidak bisa dibatalkan.',
  'No notifications yet. Things like new requests and decisions on your business show up here.': 'Belum ada notifikasi. Hal seperti permintaan baru dan keputusan untuk usahamu muncul di sini.',
  'Require applicants to provide': 'Wajibkan pelamar menyertakan',
  'Demo scope: shown as an applicant count on this job, not a real push/email notification.': 'Lingkup demo: ditampilkan sebagai jumlah pelamar pada lowongan ini, bukan notifikasi push/email sungguhan.',
  'Academic': 'Akademik',
  'Employment': 'Pekerjaan',
  'Bio': 'Bio',
  'by Ikafe Undip': 'oleh Ikafe Undip',
  'News from Ikafe will show up here.':
      'Berita dari Ikafe akan muncul di sini.',
  'Welcome to Lingkaran': 'Selamat datang di Lingkaran',
  'This is a closed test. Please use test contact details. Do not upload a real CV or enter a real phone number yet. (Ini uji coba tertutup. Gunakan data kontak percobaan, jangan unggah CV asli atau isi nomor telepon asli.)': 'Ini uji coba tertutup. Gunakan data kontak percobaan, jangan unggah CV asli atau isi nomor telepon asli.',
  'Preview': 'Pratinjau',
  'Upcoming': 'Akan datang',
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
  'You have reached the product limit for this business. Your '
          'products stay visible and you can still edit or delete them. To add '
          'more, please contact an admin about unlimited posting.':
      'Batas produk untuk bisnis ini sudah tercapai. Produkmu tetap '
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
