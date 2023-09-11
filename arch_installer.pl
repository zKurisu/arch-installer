#! /usr/bin/perl
#  arch_installer.pl
#
#  To install Archlinux easily
#  Using diff arguments to install diff parts
#  'dwm'
#  Adding error handler
#  need to divide into two parts
#
#  Copyright (Perl) Jie
#  2023-03-26
#
use 5.36.0;
use File::Basename;
use Getopt::Long;

my $things_done = <<'DONE';
This script has finish the following contents:
1. install the linux structure, dhcpcd, iwd
2. set the language to English (uncomment the Chinese)
3. set the basic info (machine name, local domain)
4. change the keycode (exchange CapsLk and LCTL)
DONE

my $pay_attention = "\e[32mPlease read it carefully\e[0m 
this message will only come for one time (before creating the log file)
Before run 'perl arch_installer.pl --first' you should finish partitioning the disk
and mount it to '/mnt' and '/mnt/boot' (two partitions, one is for '/', one is for 'boot')
After that, you can run 'perl arch_installer.pl --first' to begin the installation";

my $log_file = 'archlinux_install.log';
my $current_file_name = basename($0);
unless ( -e $log_file ) {
    print "$pay_attention\n";
    system "touch $log_file" ;
}
open my $message_fh, '+<', $log_file
  or die "Can not open $log_file: $!";

my @lines      = read_file($message_fh);
my @commands_1 = (
    "timedatectl set-ntp true",
    "pacman -Syy && pacman -S archlinux-keyring --noconfirm && pacman -Syy",
    "pacstrap /mnt base base-devel linux linux-firmware",
    "genfstab -U /mnt >> /mnt/etc/fstab",
    "cp $0 /mnt/$current_file_name && cp $log_file /mnt/$log_file",
);

my @commands_2 = (
    "ln -n -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime",
    "hwclock --systohc",
    "sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen",
    "sed -i 's/^#zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen",
    "locale-gen",
    "echo 'LANG=en_US.UTF-8' >> /etc/locale.conf",
    "echo 'ArchLinux' >> /etc/hostname",
    "echo -e '127.0.0.1 localhost\\n::1 localhost\\n127.0.1.1 hostname.localdomain hostname' >> /etc/hosts",
    "echo 'ArchLinux' >> /etc/hostname",
    "pacman -Syy && pacman -S archlinux-keyring --noconfirm",
    "pacman -S intel-ucode --noconfirm",
    "pacman -S grub efibootmgr efivar os-prober --noconfirm",
    "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch --recheck",
    "grub-mkconfig -o /boot/grub/grub.cfg",
    "pacman -S dhcpcd iwd --noconfirm",
    "systemctl enable dhcpcd",
    "systemctl enable iwd",
"perl -i -ne 's/<CAPS> = \\d{2}/<CAPS> = 66/; s/<LCTL> = \\d{2}/<LCTL> = 37/; print' /usr/share/X11/xkb/keycodes/evdev",

);


Main();

sub Main {
    unless ( $ARGV[0] ) {
        print "You should run it with argument\n";
        print "Using '--help' to check the arguments\n";
    }
    GetOptions(
        'help'     => \my $is_help,
        'dwm'     => \my $is_dwm,
        'kde'     => \my $is_kde,
        'cn'      => \my $is_cn,
        'utils'      => \my $is_utils,
        'first'   => \my $first_section,
        'second'  => \my $second_section,
        'keycode' => \my $is_keycode,
    );

    if ($is_help) {
        say <<'HELP';
--help      list the arguments
--dwm       install the components of dwm
--kde       install the components of kde
--cn        change the pacman mirror to chinese version
--utils     install some useful utils
--first     run when finish partion the disk
--second    run when arch-root to /mnt
--keycode   change the keycode of CapsLk and left Ctrl
HELP
    }
    elsif ($is_dwm) {
        system "pacman -Syy";
        system "pacman -S xorg xorg-xinit xorg-server --noconfirm";
        system "git clone https://git.suckless.org/dwm \$HOME/.config/dwm;";
        system "git clone https://git.suckless.org/st \$HOME/.config/st";
        system "git clone https://git.suckless.org/dmenu \$HOME/.config/dmenu";
        system "echo 'exec startx' >> \$HOME/.bash_profile";
        system "echo 'exec dwm' >> \$HOME/.xinitrc";
    }
    elsif ($is_kde) {
        system "pacman -Syy";
        system "pacman -S xorg xorg-xinit xorg-server plasma-meta alacritty dolphin ark gwenview lolcat sl neofetch --noconfirm";
        system "echo 'exec startx' >> \$HOME/.bash_profile";
        system "echo 'exec startplasma-x11' >> \$HOME/.xinitrc";

    }
    elsif ($is_cn) {
        archlinuxcn();
        CN_pacman();
    }
    elsif ($is_utils) {
        system "pacman -S --noconfirm firefox yay";
    }
    elsif ($first_section) {
        command_handler(@commands_1);
        print "Please \e[32mchroot\e[0m to /mnt, run 'arch-chroot /mnt'\n";
    }
    elsif ($second_section) {
        command_handler(@commands_2);
        print "Please \e[32change the passwd of root\e[0m, or create a new account\n";
        print "\e[32mRun\e[0m: 'passwd root' or 'useradd -m -G wheel -s /bin/bash <username>'\n";
    }
}

sub read_file {
    my $fh    = shift;
    my @lines = ();

    while (<$fh>) {
        push @lines, $_;
    }
    return @lines;
}

sub command_handler {
    my @commands = @_;
    foreach my $command (@commands) {
        unless ( grep /\Q$command\E/, @lines ) {
            print "\e[32mRunning\e[0m command: $command Now\n";
            my $status = system "$command";

            if ( $status != 0 ) {
                print
"\e[31mSomething wrong\e[0m when running the command: $command\n $!\n";
                exit;
            }
            print {$message_fh} "$command\n";
        }
        else {
            print "\e[32mJump\e[0m command: \'$command\'\n";
        }
    }
}


sub archlinuxcn {
    my $file = '/etc/pacman.conf';
    open my $fh, ">>", $file
      or die "Can not open $file: $!";
    my @lines = read_file($fh);
    unless ( grep /archlinuxcn/, @lines ) {
        my $content = <<'ARCHLINUXCN';
[archlinuxcn] 
SigLevel= Optional TrustedOnly
Server = https://mirrors.ustc.edu.cn/archlinuxcn/$arch
ARCHLINUXCN
        system "pacman -Syyu";
        system "pacman -S archlinuxcn-keyring";
        print {$fh} $content;
        system "pacman -Syyu";
    }
}

sub CN_pacman {
    my $file = '/etc/pacman.d/mirrorlist';
    open my $fh, ">", $file
      or die "Can not open $file: $!";
    seek $fh, 0, 0;
    my @lines = read_file($fh);
    unless ( grep /China/i, @lines ) {
        my $content = <<'CNPACMAN';
# China
Server = https://mirrors.aliyun.com/archlinux/$repo/os/$arch
Server = https://repo.huaweicloud.com/archlinux/$repo/os/$arch
Server = https://archlinux.thaller.ws/$repo/os/$arch
Server = https://archlinux-br.com.br/archlinux/$repo/os/$arch
Server = https://mirror.telepoint.bg/archlinux/$repo/os/$arch
Server = https://archlinux.mailtunnel.eu/$repo/os/$arch
Server = https://mirror.cyberbits.eu/archlinux/$repo/os/$arch
Server = https://phinau.de/arch/$repo/os/$arch
Server = https://archmirror.it/repos/$repo/os/$arch
Server = https://mirror.pseudoform.org/$repo/os/$arch
Server = https://at.arch.mirror.kescher.at/$repo/os/$arch
Server = https://mirror.theo546.fr/archlinux/$repo/os/$arch
Server = https://america.mirror.pkgbuild.com/$repo/os/$arch
Server = https://asia.mirror.pkgbuild.com/$repo/os/$arch
Server = https://seoul.mirror.pkgbuild.com/$repo/os/$arch
Server = https://sydney.mirror.pkgbuild.com/$repo/os/$arch
Server = https://mirror.f4st.host/archlinux/$repo/os/$arch
Server = https://mirror.lty.me/archlinux/$repo/os/$arch
Server = https://mirror.chaoticum.net/arch/$repo/os/$arch
Server = https://mirror.osbeck.com/archlinux/$repo/os/$arch
Server = https://ftp.halifax.rwth-aachen.de/archlinux/$repo/os/$arch
Server = https://arch.mirror.constant.com/$repo/os/$arch
CNPACMAN
        print {$fh} $content;
    }
}
