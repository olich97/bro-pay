import type { Metadata } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import "./globals.css";

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
  display: 'swap',
});

const jetbrainsMono = JetBrains_Mono({
  variable: "--font-jetbrains-mono",
  subsets: ["latin"],
  display: 'swap',
});

export const metadata: Metadata = {
  title: "Bro Pay - Send Money via WhatsApp Links",
  description: "Revolutionary payment system using ERC-4337 Account Abstraction and WebAuthn passkeys. Send money as easily as sharing a WhatsApp message.",
  keywords: ["payments", "whatsapp", "crypto", "web3", "base", "erc-4337", "passkeys", "webauthn"],
  authors: [{ name: "Bro Pay Team" }],
  creator: "Bro Pay",
  publisher: "Bro Pay",
  formatDetection: {
    email: false,
    address: false,
    telephone: false,
  },
  metadataBase: new URL('https://bropay.com'),
  openGraph: {
    title: "Bro Pay - Send Money via WhatsApp Links",
    description: "Revolutionary payment system using ERC-4337 Account Abstraction and WebAuthn passkeys.",
    type: "website",
    locale: "en_US",
    siteName: "Bro Pay",
  },
  twitter: {
    card: "summary_large_image",
    title: "Bro Pay - Send Money via WhatsApp Links", 
    description: "Revolutionary payment system using ERC-4337 Account Abstraction and WebAuthn passkeys.",
    creator: "@bropay",
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="scroll-smooth">
      <body
        className={`${inter.variable} ${jetbrainsMono.variable} font-sans antialiased bg-white text-gray-900 overflow-x-hidden`}
      >
        {children}
      </body>
    </html>
  );
}
