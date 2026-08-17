import { lazyLoadControllersFromManifest } from "spree/storefront/helpers/lazy_load_controllers_with_manifest"

const controllers = ["disable-when-hidden"]
const manifest = {
  "disable-when-hidden": "ba_spree/controllers/disable_when_hidden_controller"
}

document.addEventListener('turbo:load', function () {
  const application = window.Stimulus
  lazyLoadControllersFromManifest(controllers, null, application, manifest)
})
