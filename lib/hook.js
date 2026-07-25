export const SearchableSelect = {
    mounted() {
        this.handleEvent("searchable_select", ({id}) => {
            if (this.el.id === id) {
                this.el.dispatchEvent(new Event("change", {bubbles: true}))
            }
        })
    },
}
