# Deploying Laravel to cPanel

1. Update the `.env` file with production settings.
2. Build the assets by running:
    ```sh
    npm run build
    ```
3. Zip all files and folders in the project root, including hidden ones.
4. In cPanel, navigate to your project folder, upload the zip file, and extract it.
5. Move the contents of the `public` folder to the subdomain folder (e.g., `my-project.domain.com`), except for `build/manifest.json`:
    * Keep `build/manifest.json` in the `public` folder.
    * Move all other files and folders to the subdomain folder.
6. Edit the `index.php` file in the subdomain folder, replacing `/../` with `/../PROJECT_NAME/` in three places. Save the changes.
7. In the cPanel Terminal, run:
    ```sh
    cd PROJECT_NAME
    php artisan migrate
    ```
    * If prompted about production, type `Yes`.
8. Create a symbolic link to link storage to the public folder:
    ```sh
    ln -s $HOME/PROJECT_NAME/storage/app/public $HOME/SUBDOMAIN_DIR/storage
    ```
9. Your domain is now live. Enjoy!
