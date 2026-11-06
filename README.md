# Android IL2CPP Reverse Engineering & Mod Menu Toolchain

Bu proje, köklü (rooted) Android cihazlarda çalışan Unity/IL2CPP tabanlı oyunlar üzerinde tersine mühendislik (reverse engineering), bellek analizi (memory analysis) ve dinamik yama (dynamic patching) işlemlerini otomatikleştirmek için geliştirilmiş bir araç zinciridir.

## 🚀 Özellikler
*   **Termux Entegrasyonu:** Sıfırdan Android SDK, NDK ve derleme araçlarını kurar.
*   **ELF & Bellek Analizi:** `libil2cpp.so` üzerinden sembolleri çözer, `ptrace` kullanarak canlı süreç belleğine müdahale eder.
*   **Dinamik Çağrı:** ARM64 register yönetimi ile oyun içi fonksiyonları (RPC) uzaktan tetikler.
*   **Overlay UI:** Java tabanlı, ekran üstü kontrol paneli (Floating Service).
*   **Otomatik Build:** AAPT2, JAVAC, D8 ve APK imzalama süreçlerini sıfırdan otomatik yapar.

## 🧠 Geliştirme Metodolojisi
Bu projenin mimarisi ve algoritması tamamen tarafımca tasarlanmıştır. Geliştirme sürecinde Yapay Zeka (LLM) araçları bir "asistan" olarak kullanılmıştır. Sistem tasarımı, bellek adreslerinin (offset) bulunması, `ptrace` mimarisinin kurgulanması ve hata ayıklama süreçleri tamamen manuel analiz ve yönlendirmeler ile yapılmıştır.

## ⚠️ Yasal Uyarı
Bu proje **sadece eğitim ve siber güvenlik araştırmaları** amacıyla geliştirilmiştir. Ticari oyunlarda hile yapmak etik değildir. Tersine mühendislik çalışmaları, güvenlik açıklarını tespit etmek ve sistem mimarisini anlamak için bir araçtır.
