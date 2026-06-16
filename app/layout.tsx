import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Lab Results Explainer",
  description:
    "Plain-language educational context for your lab results. Not a diagnostic tool.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
