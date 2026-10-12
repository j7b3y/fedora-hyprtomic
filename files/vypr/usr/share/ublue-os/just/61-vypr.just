# Vypr ujust recipes (latest-vypr image only; folded into 60-custom.just by
# vypr-finalize.sh during the image build).
#
# Vypr shows Windows-VM applications as native windows:
# https://github.com/Amzi-01/Vypr - host binaries are built into this image,
# the VM-side half is `ujust vypr-guest-exe` + vypr-setup.exe inside Windows.

# Configure an existing libvirt VM for Vypr: shared memory, no USB tablet,
# audio, optional virtiofs folder share, qemu.conf (root steps after
# confirmation), host->guest key and ~/.config/vypr/config. Idempotent; an
# existing config is never rewritten. Run again whenever you like.
# (This does NOT create a VM - see vypr-create-vm below.)
vypr-setup:
    @/usr/bin/hyprtomic-vypr-setup

# Create a Vypr-ready Windows VM (UEFI + Secure Boot + TPM 2.0, SATA disk,
# e1000e NIC) with virt-install. Pass the Windows ISO as the argument; an
# optional passed-through GPU is attached at creation (with its audio
# function). Finish the Windows installation in the virt-manager console,
# then run 'ujust vypr-setup'.
# Example: ujust vypr-create-vm ~/Downloads/Windows11.iso
vypr-create-vm iso:
    @/usr/bin/hyprtomic-vypr-create-vm "{{ iso }}"

# Vypr's own health check: qemu.conf user/group, whether the running VM's
# memory is readable, the guest SSH link, shared folder, UAC and notifications.
vypr-doctor:
    @vypr doctor

# Copy vypr-setup.exe to ~/Downloads and print the guest public key. Run the
# exe inside Windows and paste the key into it.
vypr-guest-exe:
    @/usr/bin/hyprtomic-vypr-setup --guest-exe

# List the Windows applications registered with Vypr.
vypr-apps:
    @vypr apps

# Find applications on the guest desktop (shortcuts and Steam entries), list
# them and register the ones you pick. Starts the VM if needed.
vypr-detect:
    @vypr detect

# Open a Linux file in the Windows application that handles it (one file, no
# default-handler changes).
vypr-open path:
    @vypr open "{{ path }}"

# Make double-clicking .psd/.exe/etc. open them in the VM. Undo: `vypr
# associate --remove`.
vypr-associate:
    @vypr associate

# Print the steps to move the passed-through GPU between host and guest
# (experimental; upstream's instructions, run them yourself).
vypr-gpu-swap:
    @vypr --debug gpu-swap --enable

# Show whether the GPU swap is wired up and which card would move.
vypr-gpu-swap-status:
    @vypr --debug gpu-swap status
