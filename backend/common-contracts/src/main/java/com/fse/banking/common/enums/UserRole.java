package com.fse.banking.common.enums;

public enum UserRole {
    CUSTOMER("ROLE_CUSTOMER"),
    TELLER("ROLE_TELLER"),
    ADMIN("ROLE_ADMIN");

    private final String authority;

    UserRole(String authority) {
        this.authority = authority;
    }

    public String getAuthority() {
        return authority;
    }

    public static UserRole fromAuthority(String authority) {
        if (authority == null) {
            return null;
        }
        for (UserRole role : values()) {
            if (role.name().equalsIgnoreCase(authority) || role.authority.equalsIgnoreCase(authority)) {
                return role;
            }
        }
        throw new IllegalArgumentException("Unknown role authority: " + authority);
    }
}
