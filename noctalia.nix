{ pkgs, inputs, ... }:
let
  # Noctalia 5.3 requests the outputs event, which the pinned Umbriel rejects.
  # Remove this patch once Umbriel gains that subscription event.
  noctalia = inputs.noctalia.packages.${pkgs.system}.default.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./patches/noctalia-umbriel-events.patch ];
  });
in
{
  environment.systemPackages = [ noctalia ];
}
