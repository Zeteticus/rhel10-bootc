FROM registry.redhat.io/rhel10/rhel-bootc:latest

# Install OpenSCAP and security profiles
RUN dnf install -y \
    openscap-scanner \
    scap-security-guide \
    aide \
    audit \
    rsyslog \
    chrony \
    && dnf clean all

# Apply STIG security profile during build
# Note: This applies hardening rules that can be safely applied in a container context
RUN oscap xccdf eval \
    --profile xccdf_org.ssgproject.content_profile_stig \
    --remediate \
    --results /tmp/stig-results.xml \
    --report /tmp/stig-report.html \
    /usr/share/xml/scap/ssg/content/ssg-rhel10-ds.xml || true

# Configure additional STIG-compliant settings
RUN systemctl enable chronyd && \
    systemctl enable auditd && \
    systemctl enable rsyslog

# Set up AIDE database initialization (will complete on first boot)
RUN aide --init || true && \
    if [ -f /var/lib/aide/aide.db.new.gz ]; then \
        mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz; \
    fi

# Configure bootc-specific settings
RUN echo 'GRUB_CMDLINE_LINUX_DEFAULT="audit=1 audit_backlog_limit=8192"' >> /etc/default/grub

# Clean up temporary files
RUN rm -f /tmp/stig-results.xml /tmp/stig-report.html

# Ensure proper permissions for bootc
RUN chmod -R go-w /etc /usr/lib/systemd/system
