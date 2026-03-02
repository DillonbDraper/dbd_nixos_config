{ ... }:

{
  xdg.configFile."kitty/sessions/fos_bjj.session".text = ''
    # OSSBJJ (server in a persistent shell)
    new_tab OSSBJJ
    cd ~/fos_bjj
    launch --title "OSSBJJ" zsh -c "direnv exec $HOME/fos_bjj zsh -ic 'dbstop; dbstart; echo Waiting for DB...; until pg_isready -q; do sleep 0.5; done; echo DB ready.; iex -S mix phx.server; exec zsh'"

    # OpenCode (persistent shell) — wait for Phoenix server before launching so Tidewave MCP can connect
    new_tab OpenCode
    cd ~/fos_bjj
    launch --title "Opencode" zsh -ic 'echo "Waiting for Phoenix server..."; until curl -sf http://localhost:4000 > /dev/null; do sleep 1; done; echo "Phoenix ready."; opencode; exec zsh'

    # Generic scratchpad terminal
    new_tab Scratch Term
    cd ~/fos_bjj
    launch --title "Scratch" zsh
  '';

  xdg.configFile."kitty/sessions/member_doc.session".text = ''
    # Member Doc server (Phoenix backend)
    new_tab Member Doc
    cd ~/member-doc
    launch --title "Member Doc" zsh -c "direnv exec $HOME/member-doc zsh -ic 'dbstop; dbstart; echo Waiting for DB...; until pg_isready -q; do sleep 0.5; done; echo DB ready.; iex -S mix phx.server; exec zsh'"

    # React client
    new_tab Client
    cd ~/member-doc/client
    launch --title "Client" zsh -c "direnv exec $HOME/member-doc zsh -ic 'npm run local; exec zsh'"

    # Claude Code — wait for Phoenix server before launching
    new_tab Claude
    cd ~/member-doc
    launch --title "Claude" zsh -ic 'echo "Waiting for Phoenix server..."; until curl -sf http://localhost:4000 > /dev/null; do sleep 1; done; echo "Phoenix ready."; claude; exec zsh'

    # Generic scratchpad terminal
    new_tab Scratch Term
    cd ~/member-doc
    launch --title "Scratch" zsh
  '';
}
