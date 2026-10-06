class UserPersona {
  final String name;
  final String role;
  final String email;
  final String password;
  final String accountId;
  final double balance;

  const UserPersona({
    required this.name,
    required this.role,
    required this.email,
    required this.password,
    required this.accountId,
    required this.balance,
  });

  static const List<UserPersona> demoPersonas = [
    UserPersona(
      name: 'Juan Dela Cruz',
      role: 'Customer',
      email: 'juan.dc@email.com',
      password: 'password123',
      accountId: '1000-2000-3001',
      balance: 15000000.00,
    ),
    UserPersona(
      name: 'Maria Clara Reyes',
      role: 'Customer',
      email: 'maria.reyes@email.com',
      password: 'password123',
      accountId: '1000-2000-3002',
      balance: 5000000.00,
    ),
    UserPersona(
      name: 'Diana Vance',
      role: 'Admin / Teller',
      email: 'diana.admin@bank.com',
      password: 'password123',
      accountId: '1000-8800-9902',
      balance: 450000.00,
    ),
  ];
}
