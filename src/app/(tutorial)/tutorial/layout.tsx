import Logo from '@/components/Logo';

export default function TutorialLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <>
      <Logo />
      {children}
    </>
  );
}
