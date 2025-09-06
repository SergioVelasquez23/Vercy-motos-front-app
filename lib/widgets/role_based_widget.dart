import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class RoleBasedWidget extends StatelessWidget {
  final Widget child;
  final List<String> allowedRoles;
  final Widget? fallback;
  final bool requireAll;

  /// Creates a widget that only displays its child if the current user has the required roles
  ///
  /// Parameters:
  /// - child: The widget to display if the user has the required roles
  /// - allowedRoles: List of roles that are allowed to see this widget
  /// - fallback: Widget to show if the user doesn't have the required roles (null hides completely)
  /// - requireAll: If true, the user must have ALL the specified roles. If false, ANY role is sufficient.
  const RoleBasedWidget({
    super.key,
    required this.child,
    required this.allowedRoles,
    this.fallback,
    this.requireAll = false,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    bool hasAccess = false;

    if (requireAll) {
      // User must have ALL specified roles
      hasAccess = allowedRoles.every((role) => userProvider.hasRole(role));
    } else {
      // User must have ANY of the specified roles
      hasAccess = userProvider.hasAnyRole(allowedRoles);
    }

    if (hasAccess) {
      return child;
    } else {
      return fallback ??
          const SizedBox(); // Empty widget if no fallback provided
    }
  }
}
