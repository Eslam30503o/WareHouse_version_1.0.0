using Microsoft.AspNetCore.Mvc;
using WarehouseApp.Data;
using WarehouseApp.Models;
using System.Linq;

namespace WarehouseApp.Controllers
{
    public class ItemsController : Controller
    {
        private readonly AppDbContext _context;

        public ItemsController(AppDbContext context)
        {
            _context = context;
        }

        public IActionResult Index()
        {
            var items = _context.Items.ToList();

            if (!items.Any())
            {
                Console.WriteLine("No items found in database!");
            }
            else
            {
                Console.WriteLine($"Found {items.Count} items.");
            }

            return View(items);
        }

        public IActionResult Create()
        {
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Create(Item item)
        {
            if (ModelState.IsValid)
            {
                item.LastUpdate = DateTime.Now;  //  ⁄ÌÌ‰  «—ÌŒ «· ÕœÌÀ «·Õ«·Ì
                _context.Items.Add(item);
                _context.SaveChanges();
                return RedirectToAction(nameof(Index));
            }
            return View(item);
        }
    }
}
