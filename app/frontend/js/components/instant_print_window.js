import {QZStatusBanner} from "./qz/status_banner";
import {QZErrorBanner} from "./qz/error_banner";
import {PrintButton} from "./qz/print_button";
export function InstantPrintWindow() {
    qz_state.pdf_url = this.pdf_url
    return html`<div>
        ${$if(
            use(qz_settings.printer, (p) => (qz_settings.printer === 'pick a printer...' || !qz_settings.printer)),
            html`
            <div class="banner banner-info">
                you need to <a href="/qz_tray/settings">set up your printer</a> :-P
            </div>
            `
        )}
        <${QZStatusBanner}/>
        <${QZErrorBanner}/>
        <${PrintButton}/>
    </div>`
}