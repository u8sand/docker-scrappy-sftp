# Scrappy SFTP is a multi-user SFTP server with emailed transfer logs.

FROM alpine:3.6
MAINTAINER Daniel J. B. Clarke <u8sand@gmail.com>

# SFTP on port 22.
EXPOSE 22

# Volumes hold privates SFTP directories of each user and user/group/host credentials.
VOLUME ["/sftp-root", "/creds"]

# Install dependencies.
RUN set -x \
  && apk add --no-cache \
    inotify-tools \
    openssh \
    python3 \
    rsync \
    shadow \
    ssmtp \
    supervisor \
  && mkdir -p /var/run/sshd \
  # The sftp group is for all SFTP users including sftpadmin.
  && groupadd sftp \
  # Create sftpadmin with password "sftpadmin".
  && useradd -d / -g sftp -M sftpadmin -s /bin/false \
    -p '$6$RxQyRXO3$IBErDaNVy4uKXjazOFyLHm4jFdsPLCloR52bpT3KDyAdcKHV/HlX.vO3/8x22f5PTMWFP7e.aB.D4mu.7nWXW1'

# Reconfigure sshd to use in-process SFTP server and chroot the sftp group.
RUN sed -e 's|\(Subsystem sftp \).*|\1internal-sftp -l INFO|' -i /etc/ssh/sshd_config && \
 echo >>/etc/ssh/sshd_config && \
 echo '# SFTP Jailed users' >>/etc/ssh/sshd_config && \
 echo >>/etc/ssh/sshd_config && \
 echo 'Match user sftpadmin' >>/etc/ssh/sshd_config && \
 echo '    ChrootDirectory /sftp-root' >>/etc/ssh/sshd_config && \
 echo >>/etc/ssh/sshd_config && \
 echo 'Match group sftp' >>/etc/ssh/sshd_config && \
 echo '    X11Forwarding no' >>/etc/ssh/sshd_config && \
 echo '    AllowTcpForwarding no' >>/etc/ssh/sshd_config && \
 echo '    ChrootDirectory /sftp-root/%u' >>/etc/ssh/sshd_config && \
 echo '    AuthorizedKeysFile /sftp-root/%u/.ssh/authorized_keys' >>/etc/ssh/sshd_config && \
 echo '    ForceCommand internal-sftp -l INFO' >>/etc/ssh/sshd_config && \
 # Make all files group writeable so they can be modified by either sftpadmin or the unprivileged users.
 echo >>/etc/pam.d/sshd && \
 echo '# UMask for chrooted SFTP users' >>/etc/pam.d/sshd && \
 echo 'session optional pam_umask.so umask=002' >>/etc/pam.d/sshd

# Entry point and command.
ENTRYPOINT ["/usr/local/bin/sftpenv"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/scrappysftp.conf"]

# Add configuration for supervisord
COPY supervisord.conf /etc/supervisor/conf.d/scrappysftp.conf

# Add transfer log mailer daemon and utility scripts.
COPY bin/* /usr/local/bin/
