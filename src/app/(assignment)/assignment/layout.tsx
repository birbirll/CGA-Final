import Logo from '@/components/Logo';

export default function AssignmentLayout({
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
