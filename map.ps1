Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

[xml]$xaml = 
@"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="Window"
        Width="800"
        Height="600"
 
        ShowInTaskbar="True">
    <Grid Margin="20" ClipToBounds="True">
    <Canvas Name="canvas"/>
    </Grid>
</Window>
"@
 
$xaml_reader = New-Object System.Xml.XmlNodeReader $xaml
[System.Windows.Window]$window = [Windows.Markup.XamlReader]::Load($xaml_reader)




[System.Windows.Controls.Canvas]$canvas = $window.FindName("canvas")

$canvas.Background = [System.Windows.Media.Brushes]::Blue
$isDown = 0
$zoom = 2
$scale = 1
$tileCount = [Math]::Pow(2,$zoom)
$tileRanges = @{left=0;right=-1;top=0;bottom=-1;}
$pixelRanges = @{left=0;right=0;top=0;bottom=0;}

   

    function Update
    { 
        if($canvas.Children.Count -eq 0) {return}

        $rightEdge = [double]::NegativeInfinity
        $rightX = 0
        $leftEdge = [double]::PositiveInfinity
        $leftX = 0
        $topEdge = [double]::PositiveInfinity
        $topY = 0
        $bottomEdge = [double]::NegativeInfinity
        $bottomY = 0
        foreach($child in $canvas.Children)
        {
            $childLeft = [System.Windows.Controls.Canvas]::GetLeft($child)
            $childTop = [System.Windows.Controls.Canvas]::GetTop($child)       
            $childRight = $childLeft + $child.Width
            $childBottom = $childTop + $child.Height
            if($childRight -gt $rightEdge) {$rightEdge = $childRight; $rightX = $child.Tag.X}
            if($childLeft -lt $leftEdge) {$leftEdge = $childLeft; $leftX = $child.Tag.X}
            if($childTop -lt $topEdge) {$topEdge = $childTop; $topY = $child.Tag.Y}
            if($childBottom -gt $bottomEdge) {$bottomEdge = $childBottom; $bottomY = $child.Tag.Y}  
        }
        $tileRanges.right = $rightX
        $tileRanges.left = $leftX
        $tileRanges.top = $topY
        $tileRanges.bottom = $bottomY
        $pixelRanges.right = $rightEdge
        $pixelRanges.left = $leftEdge
        $pixelRanges.top = $topEdge
        $pixelRanges.bottom =$bottomEdge

    }
    
    function LoadTiles
    {
        $rightX = $tileRanges.right
        $leftX = $tileRanges.left
        $topY = $tileRanges.top
        $bottomY = $tileRanges.bottom

        $rightEdge = $pixelRanges.right
        $leftEdge = $pixelRanges.left
        $topEdge = $pixelRanges.top
        $bottomEdge = $pixelRanges.bottom
    
        while($rightEdge -lt $canvas.ActualWidth)
        {
            $x = $rightEdge
            $y = $topEdge

            $XX = $rightX + 1
            $XX = $XX % $tileCount
            $YY = $topY

            while($y -lt $bottomEdge)
            {
                addTile @{Z=1;X=$XX;Y=$YY} "https://tile.openstreetmap.org/$zoom/$XX/$YY.png" $x $y ($scale*256) ($scale*256)
                $y += $scale*256
                $YY += 1
                $YY = $YY % $tileCount
            }
            $rightX = $XX
            $rightEdge += $scale*256
        }

        while($leftEdge -gt 0)
        {
            $x = $leftEdge - $scale*256
            $y = $topEdge

            $XX = $leftX - 1
            if($XX -lt 0){$XX += $tileCount}
            $YY = $topY

            while ($y -lt $bottomEdge) 
            {
                addTile @{Z=1;X=$XX;Y=$YY} "https://tile.openstreetmap.org/$zoom/$XX/$YY.png" $x $y ($scale*256) ($scale*256)
                $y += $scale*256
                $YY = ($YY + 1) % $tileCount
            }
            $leftX = $XX
            $leftEdge -= $scale*256
        }

        while($topEdge -gt 0)
        {
            $x = $leftEdge
            $y = $topEdge - $scale*256

            $XX = $leftX
            $YY = $topY - 1
            if($YY -lt 0) {$YY += $tileCount}


            while ($x -lt $rightEdge) 
            {
                addTile @{Z=1;X=$XX;Y=$YY} "https://tile.openstreetmap.org/$zoom/$XX/$YY.png" $x $y ($scale*256) ($scale*256)
                $x += $scale*256
                $XX = ($XX + 1) % $tileCount
            }
            $topY = $YY
            $topEdge -= $scale*256
        }

        while($bottomEdge -lt $canvas.ActualHeight)
        {
            $x = $leftEdge
            $y = $bottomEdge

            $XX = $leftX
            $YY = $bottomY + 1
            $YY = $YY % $tileCount

            while ($x -lt $rightEdge) 
            {
                addTile @{Z=1;X=$XX;Y=$YY} "https://tile.openstreetmap.org/$zoom/$XX/$YY.png" $x $y ($scale*256) ($scale*256)
                $x += $scale*256
                $XX = ($XX + 1) % $tileCount
            }
            $bottomY = $YY
            $bottomEdge += $scale*256
        }

    }

    function RemoveTiles
    {

       $toRemove = @()
       foreach($child in $canvas.Children)
       {
           $childLeft = [System.Windows.Controls.Canvas]::GetLeft($child)
           $childTop = [System.Windows.Controls.Canvas]::GetTop($child)
       
           if(
               $childLeft -gt $canvas.ActualWidth -or
               $childTop -gt $canvas.ActualHeight -or
               $childLeft -lt  -$child.ActualWidth -or
               $childTop -lt -$child.ActualHeight) {$toRemove += $child}
        }

        foreach($child in $toRemove)
        {
            $canvas.Children.Remove($child)
        }

    }

    function ResizeTiles
    {
        foreach($child in $canvas.Children)
        {
            $offsetLeft = $pixelRanges.left + $child.Tag.X * $scale * 256
            $offsetTop = $pixelRanges.top + $child.Tag.Y * $scale * 256

            [System.Windows.Controls.Canvas]::SetLeft($child, $offsetLeft)
            [System.Windows.Controls.Canvas]::SetTop($child, $offsetTop)
            $child.Width = $scale * 256
            $child.Height = $scale * 256
        }

    }

$canvas.Add_MouseDown({
    param($sender, $e)
    $pos = $e.GetPosition($canvas)
    $global:x = $pos.X
    $global:y = $pos.Y
    $global:isDown = 1
})

$window.Add_MouseUp({
    param($sender, $e)
    $global:x = 0
    $global:y = 0
    $global:isDown = 0
})

$window.Add_MouseMove({
    param($sender, $e)
    if($isDown -eq 0) {return}
    $currentPos = $e.GetPosition($canvas)
    $dx = $currentPos.X - $x
    $dy = $currentPos.Y - $y
    $global:x = $currentPos.X
    $global:y = $currentPos.Y

    foreach($child in $canvas.Children)
    {
        $prevX = [System.Windows.Controls.Canvas]::GetLeft($child)
        $prevY = [System.Windows.Controls.Canvas]::GetTop($child)

        [System.Windows.Controls.Canvas]::SetLeft($child, $prevX+$dx)
        [System.Windows.Controls.Canvas]::SetTop($child, $prevY+$dy)
    }

    Update
    RemoveTiles
    LoadTiles


    
    
    
})


$window.Add_SizeChanged({
    Update
    RemoveTiles
    LoadTiles
    Update
    
})

$canvas.Add_MouseWheel({
    param($sender, $e)
    
    if($e.Delta -gt 0)
    {
        $global:scale += 0.1
    }
    else 
    {
        if($scale -gt 0.5)
        {
            $global:scale -= 0.1
        }
    }
    ResizeTiles
    Update
    RemoveTiles
    LoadTiles
    Update
    
})


function addTile
{
    param (
        $tag = @{},
        [string]$url,
        [double]$x=0,
        [double]$y=0,
        [double]$width=256,
        [double]$height=256
    )

    [System.Windows.Controls.Image] $image = New-Object System.Windows.Controls.Image
    $image.Source = New-Object System.Windows.Media.Imaging.BitmapImage(New-Object System.Uri($url))
    $image.Width = $width
    $image.Height = $height
    $image.Tag = $tag
    
    [System.Windows.Controls.Canvas]::SetLeft($image,$x)
    [System.Windows.Controls.Canvas]::SetTop($image,$y)

    $canvas.AddChild($image)
}





$result = $window.ShowDialog()



