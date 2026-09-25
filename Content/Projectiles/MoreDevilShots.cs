using Terraria.ID;

namespace ChainsawManMod.Content.Projectiles
{
	// Angel Devil: feathers that slow the player.
	public class FeatherBolt : DevilShotBase
	{
		protected override int DustType => DustID.WhiteTorch;
		protected override int DebuffType => BuffID.Slow;
		protected override bool Spins => false;
		protected override int Size => 10;
	}

	// Curse Devil: nails that curse the player (no item use while cursed).
	public class CurseNail : DevilShotBase
	{
		protected override int DustType => DustID.Smoke;
		protected override int DebuffType => BuffID.Cursed;
		protected override bool Spins => false;
		protected override int Size => 10;
	}

	// Typhoon Devil: gusts of wind.
	public class WindBolt : DevilShotBase
	{
		protected override int DustType => DustID.Cloud;
		protected override int Size => 18;
	}

	// Darkness Devil: shadow bolts that blind the player.
	public class DarkBolt : DevilShotBase
	{
		protected override int DustType => DustID.Smoke;
		protected override int DebuffType => BuffID.Darkness;
		protected override int Size => 16;
	}
}
