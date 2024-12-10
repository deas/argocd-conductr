#!/usr/bin/env bb
(ns split-k8s-manifests
  (:require [clojure.java.io :as io]
            [clojure.string :as str]
            [clj-yaml.core :as yaml]))

(defn load-yaml-stream [file-path]
  "Loads a YAML stream into a sequence of resources."
  (with-open [rdr (io/reader file-path)]
    (doall (yaml/parse-stream rdr {:load-all true}))))

(defn save-yaml [file-path data]
  "Writes YAML data to a file."
  (println file-path " " (sequential? data))
  (with-open [wrtr (io/writer file-path)]
    (.write wrtr
           (if (sequential? data)
             (->> data
                 (map #(yaml/generate-string % :dumper-options {:flow-style :block}))
                 (str/join "---\n"))
              (yaml/generate-string data :dumper-options {:flow-style :block})))))

(defn process-resources [resources output-dir suffix]
  "Processes the resources and writes them into categorized files."
  #_(println resources)
  (let [crds (filter #(= "CustomResourceDefinition" (:kind %)) resources)
        rbac-kinds #{"Role" "ClusterRole" "RoleBinding" "ClusterRoleBinding"}
        rbac (filter #(contains? rbac-kinds (:kind %)) resources)
        others (remove #(or (= "CustomResourceDefinition" (:kind %))
                            (contains? rbac-kinds (:kind %))) resources)]

    ;; Save CRDs
    (when (seq crds)
      (save-yaml (str output-dir "/crds" suffix ".yaml") crds))

    ;; Save RBAC resources
    (when (seq rbac)
      (save-yaml (str output-dir "/rbac" suffix ".yaml") rbac))

    ;; Save other resources individually
    (doseq [resource others]
      (let [kind (:kind resource)
            name (get-in resource [:metadata :name])
            file-path (str output-dir "/" kind "-" name ".yaml")]
        (save-yaml file-path resource)))))

(defn -main [& args]
  (let [input-file (first args)
        suffix (or (second args) "")
        resources (load-yaml-stream input-file) ]
    ;; (println args)
    ;; (println input-file)
    (process-resources resources "." suffix)
    ))

(when (= *file* (System/getProperty "babashka.file"))
  (apply -main *command-line-args*))
