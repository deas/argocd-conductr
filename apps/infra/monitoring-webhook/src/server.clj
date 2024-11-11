#!/usr/bin/env bb

(require '[org.httpkit.server :as http])

(defn handler [req]
  (let [headers (get req :headers)
        path          (:uri req)
        query-string  (:query-string req)
        body    (when-let [b (:body req)]
                  (slurp b))]
    (when (not (= path "/health"))
       (println (assoc req :body body)))

    {:status  200
     :headers {"Content-Type" "text/plain"}
     :body    "Received!"}))

(http/run-server handler {:port 8080})

(println "Server running on port 8080")

@(promise)
