# fish-helix
Helix editor style key bindings for fish shell

## Installation

```sh
fisher install sanghanan/fish-helix
```

## Usage

Enable the keybindings by setting:

```fish
fish_helix_key_bindings
```

Remove them using:
```fish
fish_default_key_bindings
```

## Recent Changes

- Simplified implementation using direct command chains
- Fixed `gl` command
- Removed Indicators for modes [I],[N] or [G] since I found them distracting.
