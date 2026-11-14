import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_theme.dart';
import '../../models/employee.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  EmployeeRole _selectedRole = EmployeeRole.SALES_REP;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadUsers();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    final email = value.trim();
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    // Clear previous inline messages
    final userProvider = context.read<UserProvider>();
    userProvider.clearMessages();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();
    final role = _selectedRole.name;

    final messenger = ScaffoldMessenger.of(context);

    final success = await userProvider.createUser(
      email: email,
      password: password,
      role: role,
      name: name.isNotEmpty ? name : null,
    );

    if (!mounted) return;

    if (success) {
      // Clear password field immediately
      _passwordController.clear();
      _nameController.clear();
      _emailController.clear();
      _formKey.currentState?.reset();
      setState(() {
        _selectedRole = EmployeeRole.SALES_REP;
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            userProvider.successMessage ?? 'User created successfully.',
          ),
          backgroundColor: AppColors.callGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(userProvider.errorMessage ?? 'Failed to create user.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color _getRoleBadgeColor(EmployeeRole role) {
    switch (role) {
      case EmployeeRole.ADMIN:
        return AppColors.primary;
      case EmployeeRole.MANAGER:
        return AppColors.tempWarm;
      case EmployeeRole.SALES_REP:
        return AppColors.callGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final currentEmployee = authProvider.currentEmployee;

    // Security check: only ADMIN can access this screen
    if (currentEmployee != null && !currentEmployee.isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: AppColors.surface,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.lock_person_rounded,
                  size: 64,
                  color: AppColors.danger,
                ),
                SizedBox(height: 16),
                Text(
                  'Administrator Privileges Required',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Only users with the Administrator role can access user management and create new CRM accounts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Manage Users',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Users',
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: userProvider.isLoading
                ? null
                : () => userProvider.loadUsers(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceElevated,
          onRefresh: () => userProvider.loadUsers(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Form Card: Add New User
                _buildAddUserCard(userProvider),

                const SizedBox(height: 28),

                // Section Header: Existing Users
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'EXISTING USERS',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.radiusPill,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '${userProvider.userCount} TOTAL',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // User List or Status
                _buildUserListSection(userProvider),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddUserCard(UserProvider userProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: AppRadius.radiusMd,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person_add_alt_1_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Add New CRM User',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Optional Full Name Field
            const Text(
              'Full Name (Optional)',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: 'e.g. John Doe',
                prefixIcon: Icon(
                  Icons.badge_outlined,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Email Field
            const Text(
              'Email Address *',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              validator: _validateEmail,
              decoration: const InputDecoration(
                hintText: 'e.g. john@suniti.com',
                prefixIcon: Icon(
                  Icons.mail_outline_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Password Field with Show/Hide Toggle
            const Text(
              'Password *',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              validator: _validatePassword,
              decoration: InputDecoration(
                hintText: 'Minimum 6 characters',
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Role Dropdown
            const Text(
              'Role *',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<EmployeeRole>(
              initialValue: _selectedRole,
              dropdownColor: AppColors.surfaceElevated,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                prefixIcon: Icon(
                  Icons.security_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ),
              items: EmployeeRole.values.map((role) {
                return DropdownMenuItem<EmployeeRole>(
                  value: role,
                  child: Text(
                    role.displayName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (role) {
                if (role != null) {
                  setState(() {
                    _selectedRole = role;
                  });
                }
              },
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: userProvider.isCreating ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusMd,
                  ),
                  elevation: 0,
                ),
                child: userProvider.isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserListSection(UserProvider userProvider) {
    if (userProvider.isLoading && userProvider.users.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (userProvider.errorMessage != null && userProvider.users.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.dangerSurface,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                userProvider.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => userProvider.loadUsers(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (userProvider.users.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Column(
            children: const [
              Icon(
                Icons.group_off_rounded,
                size: 36,
                color: AppColors.textMuted,
              ),
              SizedBox(height: 12),
              Text(
                'No Users Found',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Use the form above to provision CRM team accounts.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: userProvider.users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final user = userProvider.users[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(Employee user) {
    final roleColor = _getRoleBadgeColor(user.role);
    final initials = user.name.isNotEmpty
        ? user.name.substring(0, 1).toUpperCase()
        : user.email.substring(0, 1).toUpperCase();

    // Format creation date
    String dateStr = '';
    if (user.createdAt != null) {
      final dt = user.createdAt!;
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      dateStr = 'Joined ${dt.day} ${months[dt.month - 1]} ${dt.year}';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Initials Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: roleColor.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: roleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        user.name.isNotEmpty
                            ? user.name
                            : user.email.split('@')[0],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.15),
                        borderRadius: AppRadius.radiusSm,
                        border: Border.all(
                          color: roleColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        user.role.displayName.toUpperCase(),
                        style: TextStyle(
                          color: roleColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
