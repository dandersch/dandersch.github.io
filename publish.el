;;
;; This file is auto-generated. Any changes here will not be reflected when building.
;;

;; set package install dir to local directory
(require 'package)
(setq package-user-dir (expand-file-name "./.packages"))
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("elpa" . "https://elpa.gnu.org/packages/")
                         ("nongnu" . "https://elpa.nongnu.org/nongnu/")))
(package-initialize)
(unless package-archive-contents (package-refresh-contents))

(package-install 'htmlize) ; enable export of #+begin_src code blocks
(package-install 'glsl-mode) ; for coloring glsl src blocks

(package-install 'dash) ; used by org-id solution

(require 'cl-lib)

(require 'glsl-mode) ; syntax highlighting for glsl source blocks
(require 'ox-publish)
(require 'org)

; for :IGNORE: headlines
(package-install 'org-contrib) ; for ox-extra
(require 'ox-extra)
(ox-extras-activate '(latex-header-blocks ignore-headlines))

(require 'ob-emacs-lisp)

; NOTE: not needed for exporting roam notes (?)
;(package-install 'org-roam)
;(require 'org-roam)

(add-to-list 'load-path "~/dev/org-slide")
(require 'org-slide)

(setq
      keywords '("TITLE" "DATE" "DESCRIPTION" "IMAGE" "TAGS[]" "FILETAGS") ; keywords to parse from .org files
      org-html-htmlize-output-type 'css
      org-export-allow-bind-keywords t ; Allows #+BIND: in a buffer
      org-confirm-babel-evaluate nil   ; needed to enable org-babel src-block execution from a script
      org-src-fontify-natively t)

; set footnotes to be h3, everything else is default
(setq org-html-footnotes-section
      "<div id=\"footnotes\">\n<h3 class=\"footnotes\">%s</h3>\n<div id=\"text-footnotes\">\n%s\n</div>\n</div>")

(defun get-org-files (directory)
  "Return a list of .org files in DIRECTORY excluding 'index.org'."
  (cl-remove-if
   (lambda (file) (string-equal (concat directory "/" "index.org") file))
   (directory-files-recursively directory "\\.org$")))

(defun get-org-file-keywords (file)
  (with-temp-buffer
    (insert-file-contents file)
    (list file (org-collect-keywords keywords))))

(defun sort-keyword-list-by-date (keyword-list &optional new-to-old)
  "Sort the list by the date value of the form <YYYY-MM-DD HH:MM>"
  (sort keyword-list
        (lambda (a b)
          (let* ((date-str-a (replace-regexp-in-string "<\\[\\]>" "" (cadr (assoc "DATE" (cadr a)))))
                 (date-str-b (replace-regexp-in-string "<\\[\\]>" "" (cadr (assoc "DATE" (cadr b))))))
            (if new-to-old
              (string> date-str-a date-str-b)
              (string< date-str-a date-str-b))))))

(defun article-marked-for-noexport-p (article)
  (string-match-p (regexp-quote "noexport") (cadr (assoc "TAGS[]" (cadr article)))))

(defun keyword-value (entry key)
  "Value of KEY in an entry from the keyword lists, or nil."
  (cadr (assoc key (cadr entry))))

(defun entry-date (entry)
  "YYYY-MM-DD from an entry's DATE keyword, dropping the Org brackets and weekday."
  (when-let ((date (keyword-value entry "DATE")))
    (and (string-match "\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\)" date)
         (match-string 1 date))))

(defun entry-tags (entry)
  "FILETAGS of an entry as a list, without the empty strings the colon syntax produces."
  (when-let ((filetags (keyword-value entry "FILETAGS")))
    (cl-remove-if #'string-empty-p (split-string filetags ":"))))

(defun entry-href (entry)
  "Site path of an entry. Notes live outside the repo, so their path is rewritten."
  (if (string-prefix-p "~/org/roam" (car entry))
      (string-replace ".org" ".html" (string-replace "~/org/roam" "/notes" (car entry)))
    (concat "/" (string-replace "/index.org" "" (car entry)))))

(setq tags-to-ignore '("noexport"
                       "economics"
                       "philosophy"
                       "music"
                       "law"
                       "germany"
                       "psychology"
                       "modeling"
                       "business"
                       "engineering"
                       "physics"))
(defun roam-note-marked-for-noexport-p (article)
  "Return non-nil if the ARTICLE has one of the tags in `tags-to-ignore` in its FILETAGS."
  (let* ((filetags (cadr (assoc "FILETAGS" (cadr article))))
         (re (regexp-opt tags-to-ignore)))
    (when filetags (string-match-p re filetags))))

(defun filter-out-index-html (transcoded-data-string backend communication-channel-plist)
  (when (org-export-derived-backend-p backend 'html)
    ; NOTE "/index.html" doesn't get replaced in case of internal links for some reason...
    (string-replace "index.html" ""
                    (string-replace "/index.html" "" (substring-no-properties transcoded-data-string)))))

(add-to-list 'org-export-filter-link-functions 'filter-out-index-html)

(require 'easy-mmode)
(require 'dash)

(define-minor-mode unpackaged/org-export-html-with-useful-ids-mode
  "Attempt to export Org as HTML with useful link IDs.
stead of random IDs like \"#orga1b2c3\", use heading titles,
de unique when necessary."
  :global t
  (if unpackaged/org-export-html-with-useful-ids-mode
      (advice-add #'org-export-get-reference :override #'unpackaged/org-export-get-reference)
    (advice-remove #'org-export-get-reference #'unpackaged/org-export-get-reference)))

(defun unpackaged/org-export-get-reference (datum info)
  "Like `org-export-get-reference', except uses heading titles instead of random numbers."
  (let ((cache (plist-get info :internal-references)))
    (or (car (rassq datum cache))
        (let* ((crossrefs (plist-get info :crossrefs))
               (cells (org-export-search-cells datum))
               ;; Preserve any pre-existing association between
               ;; a search cell and a reference, i.e., when some
               ;; previously published document referenced a location
               ;; within current file (see
               ;; `org-publish-resolve-external-link').
               ;;
               ;; However, there is no guarantee that search cells are
               ;; unique, e.g., there might be duplicate custom ID or
               ;; two headings with the same title in the file.
               ;;
               ;; As a consequence, before re-using any reference to
               ;; an element or object, we check that it doesn't refer
               ;; to a previous element or object.
               (new (or (cl-some
                         (lambda (cell)
                           (let ((stored (cdr (assoc cell crossrefs))))
                             (when stored
                               (let ((old (org-export-format-reference stored)))
                                 (and (not (assoc old cache)) stored)))))
                         cells)
                        (when (org-element-property :raw-value datum)
                          ;; Heading with a title
                          (unpackaged/org-export-new-title-reference datum cache))
                        ;; NOTE: This probably breaks some Org Export
                        ;; feature, but if it does what I need, fine.
                        (org-export-format-reference
                         (org-export-new-reference cache))))
               (reference-string new))
          ;; Cache contains both data already associated to
          ;; a reference and in-use internal references, so as to make
          ;; unique references.
          (dolist (cell cells) (push (cons cell new) cache))
          ;; Retain a direct association between reference string and
          ;; DATUM since (1) not every object or element can be given
          ;; a search cell (2) it permits quick lookup.
          (push (cons reference-string datum) cache)
          (plist-put info :internal-references cache)
          reference-string))))

(defun unpackaged/org-export-new-title-reference (datum cache)
  "Return new reference for DATUM that is unique in CACHE."
  (cl-macrolet ((inc-suffixf (place)
                             `(progn
                                (string-match (rx bos
                                                  (minimal-match (group (1+ anything)))
                                                  (optional "--" (group (1+ digit)))
                                                  eos)
                                              ,place)
                                ;; HACK: `s1' instead of a gensym.
                                (-let* (((s1 suffix) (list (match-string 1 ,place)
                                                           (match-string 2 ,place)))
                                        (suffix (if suffix
                                                    (string-to-number suffix)
                                                  0)))
                                  (setf ,place (format "%s--%s" s1 (cl-incf suffix)))))))
    (let* ((title (org-element-property :raw-value datum))
           (ref (url-hexify-string (substring-no-properties title)))
           (parent (org-element-property :parent datum)))
      (while (--any (equal ref (car it))
                    cache)
        ;; Title not unique: make it so.
        (if parent
            ;; Append ancestor title.
            (setf title (concat (org-element-property :raw-value parent)
                                "--" title)
                  ref (url-hexify-string (substring-no-properties title))
                  parent (org-element-property :parent parent))
          ;; No more ancestors: add and increment a number.
          (inc-suffixf ref)))
      ref)))

(unpackaged/org-export-html-with-useful-ids-mode)

(setq comment-section-html "<hr>
<div id='comment-section'>
<h3 id='comment-section-title'>Comments</h3>
<script src='https://utteranc.es/client.js'
       repo='dandersch/andersch.dev'
       issue-term='pathname'
       label='.💬'
       theme='photon-dark'
       crossorigin='anonymous'
       async>
</script>
<script type='text/javascript'>
const commentSectionTitle = document.getElementById('comment-section-title');
const commentsDiv         = document.getElementById('comment-section');
commentSectionTitle.style.animation = 'loading 0.6s infinite alternate';
document.addEventListener('DOMContentLoaded', function() {
  const observer = new MutationObserver(function(mutationsList) {
    for (let mutation of mutationsList) {
      if (mutation.type === 'childList') {
        for (let node of mutation.addedNodes) {
          if (node.nodeName === 'DIV') {
            for (const child of node.children) {
              if (child.tagName === 'IFRAME') {
                child.addEventListener('load', function() {
                  commentSectionTitle.style.animation = 'none';
                });
              }
            }
          }
        }
      }
    }
  });

  observer.observe(commentsDiv, { childList: true });
});
</script>
</div>" )

; needed because otherwise footnotes will be below the comment section
(defun insert-comment-section  (contents html-backend info)
  (when (string-match "</main>" contents)
    (replace-match (concat comment-section-html "</main>") t t contents 0)))

; TODO put together to a single keyword-list
;(setq keyword-list
;  '(
;     ("article" '("article.org" (("TITLE" "Article Title") ("TAGS" "tag1 tag2"))))
;     ("project" '("project1.org" (("TITLE" "Article Title") ("TAGS" "tag1 tag2")))
;   )
(setq article-keyword-list '())
(setq project-keyword-list '())
(setq other-keyword-list   '())
(setq notes-keyword-list   '())

; usage:
;   (cadr (assoc "TITLE" (cadr (assoc "article" article)))

; NOTE workaround to pass keyword-list to a source-block in an org file
;      (else "Symbol’s function definition is void" error when publishing)
(defun get-article-keyword-list () article-keyword-list)
(defun get-project-keyword-list () project-keyword-list)
(defun get-other-keyword-list   () other-keyword-list)
(defun get-notes-keyword-list   () notes-keyword-list)

; fill & sort keyword-lists for project/, article/, other/
(defun fill-keyword-lists ()
  (dolist (article (get-org-files "article"))
    (let ((article-keywords (get-org-file-keywords article)))
      (unless (article-marked-for-noexport-p article-keywords)
        (push (get-org-file-keywords article) article-keyword-list))))
  (setq article-keyword-list (sort-keyword-list-by-date article-keyword-list t))

  (dolist (project (get-org-files "project"))
    (let ((project-keywords (get-org-file-keywords project)))
      (unless (article-marked-for-noexport-p project-keywords)
        (push (get-org-file-keywords project) project-keyword-list))))
  (setq project-keyword-list (sort-keyword-list-by-date project-keyword-list t))

  (dolist (other (get-org-files "other"))
    (let ((other-keywords (get-org-file-keywords other)))
      (unless (article-marked-for-noexport-p other-keywords)
        (push (get-org-file-keywords other) other-keyword-list))))
  (setq other-keyword-list (sort-keyword-list-by-date other-keyword-list t))

  ; article-keyword-list == (cdr (assoc "article" keyword-list))
  ;(setq keyword-list `(,(cons "article" article-keyword-list)
  ;                     ,(cons "project" project-keyword-list)
  ;                     ,(cons "other"   other-keyword-list))))
  ; TODO append
  (setq keyword-list '())
  (setq keyword-list (append keyword-list
                           `(("article" . ,article-keyword-list)
                             ("project" . ,project-keyword-list)
                             ("other"   . ,other-keyword-list)))))

; fill & sort keyword-lists for notes/ (called by roam project)
(defun roam-fill-keyword-lists ()
  (dolist (note (get-org-files org-roam-directory))
    (let ((notes-keywords (get-org-file-keywords note)))
      (unless (roam-note-marked-for-noexport-p notes-keywords)
        (push (get-org-file-keywords note) notes-keyword-list))))
  (setq notes-keyword-list (sort-keyword-list-by-date notes-keyword-list t))

  ; article-keyword-list == (cdr (assoc "article" keyword-list))
  (setq keyword-list `(,(cons "notes" notes-keyword-list)))
  )

(defun generate-main-rss-feed ()
  ; rss header, check with  https://validator.w3.org/feed/
  (with-temp-file "feed.xml"
    (insert
     (let* ((website-title "andersch.dev")
            (homepage      "https://andersch.dev")
            (rss-filepath  "/feed.xml"))
     (concat "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
             "<rss version=\"2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom\">\n"
             "<channel>\n"
             (format "<title>%s</title>\n" website-title)
             "<!-- <lastBuildDate>Wed, 15 Dec 2021 00:00:00 +0000</lastBuildDate> -->\n" ; TODO insert todays date
             (format "<atom:link href=\"%s%s\" rel=\"self\" type=\"application/rss+xml\"/>\n" homepage rss-filepath)
             (format "<link>%s</link>\n" homepage)
             "<description>Stuff on programming</description>\n"
             "<language>en-us</language>\n"))))
  ; rss entries
  (dolist (article article-keyword-list)
    (write-region
      (format
         (concat "<item>\n"
                 "<title>%s</title>\n"
                 "<link>%s</link>\n"
                 "<guid>%s</guid>\n"
                 "<description>\n"
                 "&lt;p&gt;%s&lt;/p&gt;\n"
                 "&lt;img src=\"https://andersch.dev/%s\"/&gt;\n"
                 "</description>\n"
                 "<pubDate>%s</pubDate>\n</item>\n")
            (cadr (assoc "TITLE" (cadr article)))
            (concat "https://andersch.dev/" (string-replace "/index.org" "" (car article)))
            (concat "https://andersch.dev/" (string-replace "/index.org" "" (car article)))
            (cadr (assoc "DESCRIPTION" (cadr article)))
            (concat (string-replace "index.org" "" (car article)) (cadr (assoc "IMAGE" (cadr article))))
            (format-time-string "%a, %d %b %Y %H:%M:%S %z" (seconds-to-time (org-time-string-to-time (cadr (assoc "DATE" (cadr article))))))
            )
      nil "feed.xml" 'append))
  ; rss ending
  (write-region "</channel>\n</rss>" nil "feed.xml" 'append))

(defun generate-tag-files ()

  ; collect all tags
  (setq article-tags '())
  (dolist (article article-keyword-list)
     (setq article-tags (append (split-string (cadr (assoc "TAGS[]" (cadr article)))  " +") article-tags)))
  (delete-dups article-tags)

  (setq project-tags '())
  (dolist (project project-keyword-list)
     (setq project-tags (append (split-string (cadr (assoc "TAGS[]" (cadr project)))  " +") project-tags)))
  (delete-dups project-tags)

  (setq other-tags '())
  (dolist (other other-keyword-list)
     ;(print other) ; ("other/publish/index.org" (("TITLE" "The Script ") ("DESCRIPTION" "...") ("DATE" "<..>") ("IMAGE" "preview.png") ("TAGS[]" "lisp org web")))
     (setq other-tags (append (split-string (cadr (assoc "TAGS[]" (cadr other)))  " +") other-tags)))
  (delete-dups other-tags)

  (setq notes-tags '())
  (dolist (notes notes-keyword-list)
     (setq notes-tags (cl-remove-if #'string-empty-p (append (split-string (cadr (assoc "FILETAGS" (cadr notes)))  ":") notes-tags))))
  (delete-dups notes-tags)

  (setq all-tags '())
  (setq all-tags (cl-concatenate 'list article-tags project-tags other-tags notes-tags))
  (delete-dups all-tags)

  ; generate .org files for all tags
  (dolist (tag all-tags)
    (with-temp-file (format "tag/%s.org" tag)
      (insert (format "#+TITLE: Pages tagged %s\n" tag))))

  ; append "* Articles" headline
  (dolist (tag article-tags)
    (write-region (format "* Articles tagged ~%s~\n" tag) nil (format "tag/%s.org" tag) 'append))
  ; add entry of an article to its tag.org's
  (dolist (article article-keyword-list)
    (dolist (tag (split-string (cadr (assoc "TAGS[]" (cadr article)))  " +"))
      (write-region (format "- [[../%s][%s]]\n" (car article) (cadr (assoc "TITLE" (cadr article))))
                    nil (format "tag/%s.org" tag) 'append)))

  ; append "* Projects" headline
  (dolist (tag project-tags)
    (write-region (format "* Projects tagged ~%s~\n" tag) nil (format "tag/%s.org" tag) 'append))
  ; add entry of a project to its tag.org's
  (dolist (project project-keyword-list)
    (dolist (tag (split-string (cadr (assoc "TAGS[]" (cadr project)))  " +"))
      (write-region (format "- [[../%s][%s]]\n" (car project) (cadr (assoc "TITLE" (cadr project))))
                    nil (format "tag/%s.org" tag) 'append)))

  ; append "* Other" headline
  (dolist (tag other-tags)
    (write-region (format "* Other tagged ~%s~\n" tag) nil (format "tag/%s.org" tag) 'append))
  ; add entry of other to its tag.org's
  (dolist (other other-keyword-list)
    (dolist (tag (split-string (cadr (assoc "TAGS[]" (cadr other)))  " +"))
      (write-region (format "- [[../%s][%s]]\n" (car other) (cadr (assoc "TITLE" (cadr other))))
                    nil (format "tag/%s.org" tag) 'append)))

  ; append "* Notes" headline
  (dolist (tag notes-tags)
    (write-region (format "* Notes tagged ~%s~\n" tag) nil (format "tag/%s.org" tag) 'append))
  ; add entry of notes to its tag.org's
  (dolist (notes notes-keyword-list)
    (dolist (tag (cl-remove-if #'string-empty-p (split-string (cadr (assoc "FILETAGS" (cadr notes)))  ":")))
      ; TODO hardcoded string-replace
      (write-region (format "- [[../%s][%s]]\n" (string-replace "~/org/roam" "notes" (car notes)) (cadr (assoc "TITLE" (cadr notes))))
                    nil (format "tag/%s.org" tag) 'append)))
  )

(defun  prepare-publishing (project-properties)
  (fill-keyword-lists)
  (generate-main-rss-feed)
  (generate-tag-files))

(defun  roam-prepare-publishing (project-properties)
  (roam-fill-keyword-lists))

(defun org-html-publish-to-html-noexport (plist filename pub-dir)
  "Publish an org file to HTML except one's that are tagged noexport"

  ; FILENAME is the filename of the Org file to be published
  ; PLIST is the property list for the given project
  ; PUB-DIR is the publishing directory.
  ; Return output file name

  (let ((notes-keywords (get-org-file-keywords filename)))
    (if (roam-note-marked-for-noexport-p notes-keywords)
        nil
      (org-html-publish-to-html plist filename pub-dir)))
)

(defun add-title-headline (backend)
  ; insert after :PROPERTY: drawer
  (if (string-match-p ":PROPERTIES:" (thing-at-point 'line t))
     (progn (search-forward ":END:" nil t) (forward-line 1)))
  (unless (member (org-get-title) '("andersch.dev" "Articles" "Projects" "Other" "Notes"))
  (when (eq backend 'html)
    (let* ((tags (if org-file-tags org-file-tags nil))
           (date (cadar (org-collect-keywords '("DATE"))))
           (description (cadar (org-collect-keywords '("DESCRIPTION"))))
           (title (org-get-title)))
      (insert "\n#+begin_export html\n")
      (when (or tags date)
        (insert "<div class=\"tags-date-box\">")
          (if date (insert (format "<div class=\"date\"><span class=\"timestamp\">%s</span></div>" date)))
          (when tags
              (insert "<div class=\"tags\"><code>[ ")
              (dolist (tag tags) (insert (format "<a href=\"/tag/%s.html\">%s</a> " tag tag)))
              (insert "]</code></div>"))
        (insert "</div>"))
      (when title (insert (format "<h1>%s</h1>" title)))
      (when description (insert (format "<p class=\"subtitle\">%s</p>" description)))
      (insert "\n#+end_export\n")
      )
    )
  ))
(add-hook 'org-export-before-processing-functions #'add-title-headline)

(setq andersch-dev
      (list "andersch.dev"
             :recursive            t
             :base-directory       "./"
             :publishing-directory "./"
             :publishing-function  'org-html-publish-to-html    ;; may be a list of functions
             :preparation-function 'prepare-publishing          ;; called before publishing
           ; :completion-function                               ;; called afterwards
           ; :base-extension                                    ;; extension of source files
           ; :html-extension       ""                           ;; extension of generated html files (without dot)
             :exclude  (regexp-opt '("code.org" "README.org" "publish.org")) ;; regex of files to exclude
           ; :include                                           ;; list of files to include

           ; :html-doctype "html5"                              ;; default is "xhtml-strict"
             :html-divs            '((preamble "header" "top")
                                     (content "main" "content")
                                     (postamble "footer" "postamble"))
             :html-html5-fancy     t
             ; TODO head defined else where and noweb it here
             :html-head            (concat "<link rel=\"icon\" type=\"image/x-icon\" href=\"/favicon.ico\">\n"
                                           "<link rel=\"stylesheet\" href=\"/style.css\">\n"
                                           ; NOTE import ubuntu font for now TODO embed in repo
                                           "<link rel=\"stylesheet\" type=\"text/css\" href=\"https://fonts.googleapis.com/css?family=Ubuntu:regular,bold&subset=Latin\">"
                                           "<script type=\"text/javascript\" src=\"/script.js\" defer></script>"
                                           )
             :html-preamble        t
             :html-preamble-format `(("en" ,(with-temp-buffer (insert-file-contents "header.html") (buffer-string))))
             :html-postamble       nil                       ;; don't insert a footer with a date etc.

             :html-link-home                  ""
             :html-head-include-default-style t
             :html-self-link-headlines   t ; headings contain hyperlinks to themselves

             :auto-sitemap         nil                       ;; https://orgmode.org/manual/Site-map.html
           ; :sitemap-filename     "sitemap.org"
           ; :sitemap-title
           ; :sitemap-style        'tree                     ;; list or tree
           ; :sitemap-sort-files   'anti-chronologically
             :exclude-tags         org-export-exclude-tags
             :html-prefer-user-labels  t                     ;; prefer CUSTOM_ID over auto-generated id's

             :html-format-headline-function org-html-format-headline-function
                                               ; function will be called with six arguments:
                                               ; TODO      the todo keyword (string or nil).
                                               ; TODO-TYPE the type of todo (symbol: todo, done, nil)
                                               ; PRIORITY  the priority of the headline (integer or nil)
                                               ; TEXT      the main headline text (string).
                                               ; TAGS      the tags (string or nil).
                                               ; INFO      the export options (plist).

             :makeindex            nil                       ;; https://orgmode.org/manual/Generating-an-index.html
             :with-title           nil                       ;; we include our own header
             :with-tags            nil                       ;; * headline :tag:
             :with-author          nil
             :with-creator         nil                       ;; don't include emacs and org versions in footer
             :with-toc             nil                       ;; no table of contents
             :section-numbers      nil                       ;; no section numbers for headings
             :html-validation-link nil                       ;; don't show validation link
             :time-stamp-file      nil                       ;; don't include "Created: <timestamp>" in footer
             :with-date            nil))

(setq org-roam-directory "~/org/roam") ; NOTE not part of the repo

(setq roam-andersch-dev-images
      (list "roam.andersch.dev-images"
             :base-directory org-roam-directory
             :base-extension "jpg\\|gif\\|png\\|svg\\|wasm\\|js"
             :publishing-directory "./notes/"
             :publishing-function 'org-publish-attachment))

(setq roam-andersch-dev
      (list "roam.andersch.dev"
             :recursive            nil
             :base-directory       org-roam-directory
             :publishing-directory "./notes/"
             :publishing-function  'org-html-publish-to-html-noexport
             :preparation-function 'roam-prepare-publishing
             :html-divs            '((preamble "header" "top")
                                     (content "main" "content")
                                     (postamble "footer" "postamble"))
             :html-html5-fancy     t
             ; TODO head defined else where and noweb it here
             :html-head            (concat "<title>andersch.dev</title>\n"
                                           "<link rel=\"icon\" type=\"image/x-icon\" href=\"/favicon.ico\">\n"
                                           "<link rel=\"stylesheet\" href=\"/style.css\">\n"
                                           ; NOTE import ubuntu font for now TODO embed in repo
                                           "<link rel=\"stylesheet\" type=\"text/css\" href=\"https://fonts.googleapis.com/css?family=Ubuntu:regular,bold&subset=Latin\">"
                                           "<script type=\"text/javascript\" src=\"/script.js\" defer></script>"
                                           )

             :exclude-tags             org-export-exclude-tags
             :html-self-link-headlines t   ;; headings contain hyperlinks to themselves
             :html-prefer-user-labels  t   ;; prefer CUSTOM_ID over auto-generated id's

             :html-preamble        t
             :html-preamble-format `(("en" ,(with-temp-buffer (insert-file-contents "header.html") (buffer-string))))
             :html-postamble       nil                       ;; don't insert a footer with a date etc.
             :auto-sitemap         nil
             :makeindex            nil                       ;; https://orgmode.org/manual/Generating-an-index.html
             :with-title           nil
             :with-author          nil
             :with-creator         nil                       ;; don't include emacs and org versions in footer
             :with-toc             nil                       ;; no table of contents
             :section-numbers      nil                       ;; no section numbers for headings
             :html-validation-link nil                       ;; don't show validation link
             :time-stamp-file      nil                       ;; don't include "Created: <timestamp>" in footer
             :with-date            nil))

;; TODO roam-andersch-dev-attachment

(setq org-publish-project-alist (list andersch-dev roam-andersch-dev-images roam-andersch-dev))

; caching
(setq org-publish-timestamp-directory "./.org-timestamps/")

(org-publish-remove-all-timestamps) ; call to avoid caching, NOTE: required now because of our org-id replacement

; NOTE: if broken links, try to run (org-roam-update-org-id-locations)
(setq org-id-locations-file "/home/da/org/.orgids") ; should fix broken links
(setq org-export-with-broken-links nil) ; NOTE might be needed for broken roam ID links...

; enable caching for roam.andersch.dev
(org-publish-initialize-cache "roam.andersch.dev")
(setq org-publish-use-timestamps-flag t)

(org-publish "roam.andersch.dev-images")
(org-publish "roam.andersch.dev")
(message "Build complete: roam.andersch.dev")

; NOTE caching causes problems with updating titles etc., so we reset the cache before publishing
(setq org-publish-use-timestamps-flag nil)
(org-publish "andersch.dev" t)
(message "Build complete: andersch.dev")
