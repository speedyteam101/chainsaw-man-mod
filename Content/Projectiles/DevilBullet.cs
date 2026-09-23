using Terraria.ID;

namespace ChainsawManMod.Content.Projectiles
{
	// Bullet used by the Gun Devil and Gun Devil Spawn.
	public class DevilBullet : DevilShotBase
	{
		protected override int DustType => DustID.Smoke;
		protected override int Size => 8;
		protected override bool Spins => false;
	}
}
