import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"
import { pageIsTurboPreview } from "helpers/turbo_helpers"
import { onNextEventLoopTick } from "helpers/timing_helpers"
export default class extends Controller {
  static values = { subscriptionsUrl: String }

  async connect() {
    if (!pageIsTurboPreview()) {
      if (window.notificationsPreviouslyReady) {
        onNextEventLoopTick(() => this.dispatch("ready"))
      } else {
        const firstTimeReady = await this.isEnabled()

        if (firstTimeReady) {
          onNextEventLoopTick(() => this.dispatch("ready"))
          window.notificationsPreviouslyReady = true
        }
      }
    }
  }

  async attemptToSubscribe() {
    if (this.#allowed) {
      const registration = await this.#serviceWorkerRegistration || await this.#registerServiceWorker()

      switch(Notification.permission) {
        case "denied":  { console.log("Notification.permission: denied"); break }
        case "granted": { this.#subscribe(registration); break }
        case "default": { this.#requestPermissionAndSubscribe(registration) }
      }
    } else {
      console.log("Should display not-allowed notice")
    }
  }

  async isEnabled() {
    if (this.#allowed) {
      const registration = await this.#serviceWorkerRegistration
      const existingSubscription = await registration?.pushManager?.getSubscription()

      return Notification.permission == "granted" && registration && existingSubscription
    } else {
      return false
    }
  }

  get #allowed() {
    return navigator.serviceWorker && window.Notification
  }

  get #serviceWorkerRegistration() {
    return navigator.serviceWorker.getRegistration("/service-worker.js", { scope: window.location.pathname.split('/')[1]})
  }

  #registerServiceWorker() {
    return navigator.serviceWorker.register("/service-worker.js", { scope: window.location.pathname.split('/')[1]})
  }

  async #subscribe(registration) {
    registration.pushManager
      .subscribe({ userVisibleOnly: true, applicationServerKey: this.#vapidPublicKey })
      .then(subscription => {
        this.#syncPushSubscription(subscription)
        this.dispatch("ready")
      })
  }

  async #syncPushSubscription(subscription) {
    const response = await post(this.subscriptionsUrlValue, { body: this.#extractJsonPayloadAsString(subscription), responseKind: "turbo-stream" })
    if (!response.ok) subscription.unsubscribe()
  }

  async #requestPermissionAndSubscribe(registration) {
    const permission = await Notification.requestPermission()
    if (permission === "granted") this.#subscribe(registration)
  }

  get #vapidPublicKey() {
    const encodedVapidPublicKey = document.querySelector('meta[name="vapid-public-key"]').content
    return this.#urlBase64ToUint8Array(encodedVapidPublicKey)
  }

  #extractJsonPayloadAsString(subscription) {
    const { endpoint, keys: { p256dh, auth } } = subscription.toJSON()
    return JSON.stringify({ push_subscription: { endpoint, p256dh_key: p256dh, auth_key: auth } })
  }

  // VAPID public key comes encoded as base64 but service worker registration needs it as a Uint8Array
  #urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - base64String.length % 4) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")

    const rawData = window.atob(base64)
    const outputArray = new Uint8Array(rawData.length)

    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i)
    }

    return outputArray
  }
}
