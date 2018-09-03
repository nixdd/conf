(define-module (pkgs)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages linux)
  #:use-module (guix build-system trivial)
  #:use-module (gnu)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix packages))

(define (linux-nonfree-urls version)
  "Return a list of URLs for Linux-Nonfree VERSION."
  (list (string-append
         "https://www.kernel.org/pub/linux/kernel/v4.x/"
         "linux-" version ".tar.xz")))

;; Remove this and native-inputs below to use the default config from Guix.
;; Make sure the kernel minor version matches, though.
;(define kernel-config
;  (string-append (dirname (current-filename)) "/kernel.config"))

(define-public linux-nonfree
  (package
    (inherit linux-libre)
    (name "linux-nonfree")
    (version "4.17.8")
    (source (origin
              (method url-fetch)
              (uri (linux-nonfree-urls version))
              (sha256 (base32 "0hkqypjgvr8lyskwk8z3dac8pyi4wappnk25508vs3fy08365h0k"))))
    ;(native-inputs
    ; `(("kconfig" ,kernel-config)
    ;   ,@(alist-delete "kconfig"
    ;                   (package-native-inputs linux-libre))))
    (synopsis "Stable Linux kernel, nonfree binary blobs included")
    (description "Linux is a kernel.")
    (license license:gpl2)              ;XXX with proprietary firmware
    (home-page "https://kernel.org")))


(define-public linux-firmware-non-free
  (package
    (name "linux-firmware-non-free")
    (version "8d69bab7a3da1913113ea98cefb73d5fa6988286")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git")
                    (commit version)))
              (sha256
               (base32
                "1ganxgkdxl10v0ihsp9qsaj4px8yf8kihz4gbmqyld28rqnc47zl"))))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder (begin
                   (use-modules (guix build utils))
                   (let ((source (assoc-ref %build-inputs "source"))
                         (fw-dir (string-append %output "/lib/firmware/")))
                     (mkdir-p fw-dir)
                     (copy-recursively source fw-dir)
                     #t))))

    (home-page "")
    (synopsis "Non-free firmware for Linux")
    (description "Non-free firmware for Linux")
    ;; FIXME: What license?
    (license (license:non-copyleft "http://git.kernel.org/?p=linux/kernel/git/firmware/linux-firmware.git;a=blob_plain;f=LICENCE.radeon_firmware;hb=HEAD"))))

(use-modules (gnu)
             (guix store)               ;for %default-substitute-urls
             (gnu system nss)
             (pkgs))
(use-service-modules admin base dbus mcron networking ssh desktop cups xorg avahi sound)
(use-package-modules admin certs disk fonts file libusb linux ssh 
version-control tls gnome cups suckless xdisorg wm xfce compton image-viewers xorg terminals)

(operating-system
  (host-name "nixdenv")
  (timezone "Europe/Berlin")
  (kernel linux-nonfree)
  (locale "en_US.utf8")
  (firmware (append (list
                     linux-firmware-non-free)
                    %base-firmware))

  (bootloader (bootloader-configuration
               (bootloader grub-efi-bootloader)
               (target "/boot/efi")))

  (file-systems (cons* (file-system
                         (device "/dev/sda2")
                         (mount-point "/")
                         (type "ext4"))
                       (file-system
                         (device "/dev/sda1")
                         (mount-point "/boot/efi")
                         (type "vfat"))
                       %base-file-systems))

  (users (cons (user-account
                (name "nixd")
                (comment "Elias Bögel")
                (group "users")
                (supplementary-groups '("wheel" "netdev" "audio" "video" "disk"))
                (home-directory "/home/nixd"))
               %base-user-accounts))

  (packages (cons*
             dosfstools
             nss-certs
             htop
             wpa-supplicant
             network-manager-applet
             acpid
             git
	     setxkbmap
             termite
             tint2
             sxhkd
             bspwm
             compton
             feh
             %base-packages))

  (services (cons*
             (service mcron-service-type)
             ;(gnome-desktop-service)
             ;(xfce-desktop-service)
             
             ;Printer support
             (service cups-service-type
               (cups-configuration
                 (web-interface? #t)
                 (extensions
                   (list cups-filters escpr hplip))))

             ;%desktop-services, but can replace display manager
             (slim-service)
             (screen-locker-service slock)
             (screen-locker-service xlockmore "xlock")
             (service network-manager-service-type)
             (service wpa-supplicant-service-type)
             (avahi-service)
             (udisks-service)
             (upower-service)
             (accountsservice-service)
             (colord-service)
             (geoclue-service)
             (polkit-service)
             (elogind-service)
             (dbus-service)
             (ntp-service)
             x11-socket-directory-service
             (service alsa-service-type)
             (simple-service 'mtp udev-service-type (list libmtp))
             %base-services
             )))
