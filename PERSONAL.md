# Your Pinboard

This is Amy's fork of [Milaclone](https://github.com/ellshep/milaclone), under the original MIT license. The upstream canvas, columns, nested boards, resizing, mobile views, and task editor remain the foundation.

Added: a board tree, global search, Tidy up, fit-to-board, keyboard access, on-disk backup export, and undo/redo while the server is running. Rapid changes to different fields are saved together rather than losing the earlier field during debounce.

## Run

Use Node 24 (`nvm use`), then `npm install` and `HOST=127.0.0.1 PORT=5189 npm start`. Open http://127.0.0.1:5189. On this Mac, double-click `Start Pinboard.command` to run it again. Leave that terminal running while using the app.

Your notes live in `data/board.db`, and uploads live in `public/uploads/`. Both are ignored by Git. The source fork is public; your notebook data is local and not pushed. The default server listens only on this Mac.

Export backup downloads JSON containing boards, cards, and uploaded files. Keep that file as a portable recovery copy. There is no in-app restore button yet; recovery from this JSON currently needs a script. For a direct filesystem restore, stop the server and restore a saved copy of both `data/` and `public/uploads/` together. Undo history lives only in memory and resets on server restart. The notebook itself persists across restarts. Simultaneous editing from multiple tabs is not coordinated.

The starter board is illustrative content. The starter photograph is from [Unsplash](https://images.unsplash.com/photo-1473116763249-2faaef81ccda?w=800&q=85&fit=crop). Theme tokens were adapted from Amy's Taste tool kit.
