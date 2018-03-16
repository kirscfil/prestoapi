import Routing
import Vapor
import Foundation

/// Register your application's routes here.
///
/// [Learn More →](https://docs.vapor.codes/3.0/getting-started/structure/#routesswift)
public func routes(_ router: Router) throws {
    
    router.get("menu") { (request: Request) -> Menu in
        print("request incoming")
        do {
            let menu = try MenuManager.shared.getMenu().blockingAwait()
            return menu
        } catch (let error) {
            return Menu(date: Date(), categories: [])
        }
    }
}
